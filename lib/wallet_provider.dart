import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:flutter/material.dart';
import 'package:hex/hex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/credentials.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_3wallet/blockchain_config.dart';

abstract class WalletAddressServices {
  String generateMnemonic();
  Future<String> getPrivateKey(String mnemonic);
  Future<EthereumAddress> getPublicKey(String privateKey);
}

class WalletProvider extends ChangeNotifier implements WalletAddressServices {
  String? privateKey;
  String? currentNetwork = 'ethereum';
  Web3Client? web3Client;
  double balance = 0;
  bool isConnected = false;
  bool isConnecting = false;
  EthereumAddress? currentAddress;
  bool isWalletInitialized = false;

  String? connectionError;
  Future<void> loadSavedWallet() async {
    isConnecting = true;
    notifyListeners();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      privateKey = prefs.getString('privateKey');
      String? savedNetwork = prefs.getString('currentNetwork');

      if (savedNetwork != null) {
        currentNetwork = savedNetwork;
      }

      if (privateKey != null) {
        // Get the public address from private key
        currentAddress = await getPublicKey(privateKey!);
        await initializeWeb3();
        await updateBalance();
        isWalletInitialized = true;
      }
    } catch (e) {
      print('Error loading wallet: $e');
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> importWalletFromPrivateKey(String privateKey) async {
    try {
      // Validate private key format
      if (!privateKey.startsWith('0x')) {
        privateKey = '0x$privateKey';
      }

      // Verify private key is valid
      final credentials = EthPrivateKey.fromHex(privateKey);
      currentAddress = await credentials.extractAddress();

      // Save private key
      await saveWallet(
        privateKey: privateKey,
        mnemonic: '', // Empty for imported wallets
      );

      isWalletInitialized = true;
      await updateBalance();

      notifyListeners();
    } catch (e) {
      throw Exception('Invalid private key: $e');
    }
  }

  Future<EthereumAddress> getAddressFromPrivateKey(String privateKey) async {
    try {
      if (!privateKey.startsWith('0x')) {
        privateKey = '0x$privateKey';
      }
      final credentials = EthPrivateKey.fromHex(privateKey);
      return await credentials.extractAddress();
    } catch (e) {
      throw Exception('Invalid private key: $e');
    }
  }

  Future<void> saveWallet({
    required String privateKey,
    required String mnemonic,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('privateKey', privateKey);
    await prefs.setString('mnemonic', mnemonic);
    await prefs.setString('currentNetwork', currentNetwork ?? 'ethereum');
    this.privateKey = privateKey;
    await updateBalance();
    notifyListeners();
  }

  Future<void> clearWallet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('privateKey');
    await prefs.remove('mnemonic');
    privateKey = null;
    balance = 0;
    notifyListeners();
  }

  BlockchainNetwork get selectedNetwork =>
      BlockchainConfig.networks[currentNetwork]!;

  Future<void> initializeWeb3() async {
    isConnecting = true;
    connectionError = null;
    notifyListeners();

    try {
      web3Client = Web3Client(
        selectedNetwork.rpcUrl,
        http.Client(),
      );

      // Test the connection
      await web3Client!.getNetworkId();
      isConnected = true;
      connectionError = null;
    } catch (e) {
      isConnected = false;
      connectionError = _formatErrorMessage(e.toString());
      web3Client = null;
    } finally {
      isConnecting = false;
      notifyListeners();
    }
  }

  String _formatErrorMessage(String error) {
    if (error.contains('invalid project id')) {
      return 'Invalid Infura API key. Please check your configuration.';
    } else if (error.contains('Failed to connect')) {
      return 'Network connection failed. Please check your internet connection.';
    }
    return 'Connection error: ${error.split('\n')[0]}';
  }

  Future<bool> validateNetwork() async {
    if (web3Client == null) return false;
    try {
      final networkId = await web3Client!.getNetworkId();
      return networkId == selectedNetwork.chainId;
    } catch (e) {
      return false;
    }
  }

  Future<EtherAmount> getGasPrice() async {
    if (web3Client == null) throw Exception('Web3Client not initialized');
    return await web3Client!.getGasPrice();
  }

  Future<void> switchNetwork(String networkKey) async {
    currentNetwork = networkKey;
    await initializeWeb3();
    if (privateKey != null) {
      await updateBalance();
    }
    notifyListeners();
  }

  Future<void> updateBalance() async {
    print("Helo");
    print(currentAddress);

    if (currentAddress != null && web3Client != null) {
      try {
        final balanceInWei = await web3Client!.getBalance(currentAddress!);
        balance = balanceInWei.getValueInUnit(EtherUnit.ether);
        notifyListeners();
      } catch (e) {
        print('Error updating balance: $e');
      }
    }
  }

  Future<String> sendTransaction({
    required String to,
    required double amount,
    required BigInt? gasPrice,
  }) async {
    if (privateKey == null || web3Client == null) {
      throw Exception('Wallet not initialized');
    }

    final credentials = EthPrivateKey.fromHex(privateKey!);
    final transaction = await web3Client!.sendTransaction(
      credentials,
      Transaction(
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.fromUnitAndValue(
          EtherUnit.ether,
          (amount * 1e18).toInt(),
        ),
        gasPrice: gasPrice == null
            ? null
            : EtherAmount.fromBigInt(EtherUnit.wei, gasPrice),
      ),
      chainId: selectedNetwork.chainId,
    );

    return transaction;
  }

  Future<void> loadPrivateKey() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    privateKey = prefs.getString('privateKey');
    notifyListeners();
  }

  Future<void> setPrivateKey(String privateKey) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('privateKey', privateKey);
    notifyListeners();
  }

  @override
  String generateMnemonic() {
    return bip39.generateMnemonic();
  }

  @override
  Future<String> getPrivateKey(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final master = await ED25519_HD_KEY.getMasterKeyFromSeed(seed);
    final privateKey = await HEX.encode(master.key);
    return privateKey;
  }

  @override
  Future<EthereumAddress> getPublicKey(String privateKey) async {
    final private = EthPrivateKey.fromHex(privateKey);
    final address = await private.address;
    return address;
  }
}

class WalletService {
  final Web3Client web3client;
  static const String rpcUrl = "https://rpc.bchscan.io";

  WalletService() : web3client = Web3Client(rpcUrl, http.Client());

  Future<double> getBalance(EthereumAddress address) async {
    final balance = await web3client.getBalance(address);
    return balance.getValueInUnit(EtherUnit.ether);
  }

  Future<String> sendTransaction({
    required String privateKey,
    required String to,
    required double amount,
  }) async {
    final credentials = EthPrivateKey.fromHex(privateKey);
    final transaction = await web3client.sendTransaction(
      credentials,
      Transaction(
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.fromUnitAndValue(
          EtherUnit.ether,
          BigInt.from(amount * 1e18),
        ),
      ),
      chainId: 1, // 1 for mainnet
    );
    return transaction;
  }
}
