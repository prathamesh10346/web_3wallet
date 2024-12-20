import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/credentials.dart';
import 'package:web_3wallet/wallet_provider.dart';
import 'package:web_3wallet/widget/network_selector_widget.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => WalletProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web3 Wallet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WalletHomePage(),
    );
  }
}

class WalletHomePage extends StatefulWidget {
  const WalletHomePage({super.key});

  @override
  State<WalletHomePage> createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage> {
  String? mnemonic;
  String? privateKey;
  String? publicKey;
  bool isLoading = false;
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      await provider.loadSavedWallet();
    });
    addData();
  }

  void addData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('privateKey', privateKey!);
    await prefs.setString('mnemonic', mnemonic!);
    await prefs.setString('publicKey', publicKey!);
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web3 Wallet'),
        actions: [
          NetworkSelectorWidget(),
          const SizedBox(width: 16),
        ],
      ),
      body: Consumer<WalletProvider>(
        builder: (context, provider, child) {
          if (provider.isConnecting) {
            return Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConnectionStatusWidget(),
                if (!provider.isConnected)
                  Center(
                    child: Text(
                        'Please check your network connection and API key'),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected to ${walletProvider.selectedNetwork.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (walletProvider.balance > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${walletProvider.balance} ${walletProvider.selectedNetwork.symbol}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Wallet Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wallet Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (publicKey != null) ...[
                          _buildInfoRow('Public Key:', publicKey!),
                          const SizedBox(height: 8),
                          _buildInfoRow('Private Key:',
                              '${privateKey?.substring(0, 6)}...${privateKey?.substring(privateKey!.length - 4)}'),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                              'Mnemonic:', mnemonic ?? 'Not generated'),
                        ] else
                          const Text('No wallet generated yet'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                if (!isLoading) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => isLoading = true);
                      try {
                        final newMnemonic = walletProvider.generateMnemonic();
                        final newPrivateKey =
                            await walletProvider.getPrivateKey(newMnemonic);
                        final newPublicKey =
                            await walletProvider.getPublicKey(newPrivateKey);

                        await walletProvider.saveWallet(
                          privateKey: newPrivateKey,
                          mnemonic: newMnemonic,
                        );

                        setState(() {
                          mnemonic = newMnemonic;
                          privateKey = newPrivateKey;
                          publicKey = newPublicKey.hexEip55;
                        });
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        await prefs.setString('privateKey', privateKey!);
                        await prefs.setString('mnemonic', mnemonic!);
                        await prefs.setString('publicKey', publicKey!);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Wallet generated and saved successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error generating wallet: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Generate New Wallet'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (publicKey != null) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        if (publicKey != null) {
                          Clipboard.setData(ClipboardData(text: publicKey!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Wallet address copied to clipboard'),
                            ),
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet address copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Wallet Address'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (privateKey != null) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        if (privateKey != null) {
                          Clipboard.setData(ClipboardData(text: privateKey!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Wallet address copied to clipboard'),
                            ),
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet address copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Wallet privateKey'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // In WalletHomePage widget
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => ImportWalletWidget(),
                      );
                    },
                    icon: Icon(Icons.file_upload),
                    label: Text('Import Wallet'),
                  ),
                ] else
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                const Spacer(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: publicKey != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => WalletScreen(
                              address: publicKey!,
                            )));
              },
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class WalletScreen extends StatefulWidget {
  final String address;

  const WalletScreen({Key? key, required this.address}) : super(key: key);

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSending = false;

  final WalletService _walletService = WalletService();
  String? _address;
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();

    _address = widget.address;
    _refreshBalance();
  }

  Future<void> _refreshBalance() async {
    final provider = Provider.of<WalletProvider>(context, listen: false);
    await provider.updateBalance();
  }

  Future<void> _initWallet() async {
    final provider = Provider.of<WalletProvider>(context, listen: false);
    await provider.loadPrivateKey();

    if (provider.privateKey != null) {
      final address = await provider.getPublicKey(provider.privateKey!);
      setState(() {
        _address = address.hexEip55;
      });
      _updateBalance();
    }
  }

  Future<void> _updateBalance() async {
    print("Hello");
    print(_balance);
    if (_address != null) {
      final balance = await _walletService.getBalance(
        EthereumAddress.fromHex("0xB32A859C1023545bbc4Ac44D5A3150A8bCaB5f6B"),
      );
      print(balance);
      setState(() {
        _balance = balance;
      });

      print(_balance);
    }
  }

  Future<void> _createNewWallet() async {
    final provider = Provider.of<WalletProvider>(context, listen: false);
    final mnemonic = provider.generateMnemonic();
    final privateKey = await provider.getPrivateKey(mnemonic);
    await provider.setPrivateKey(privateKey);

    // Save mnemonic securely - this is just for demonstration
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Save this mnemonic: $mnemonic')),
    );

    await _initWallet();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(walletProvider.selectedNetwork.name)),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Address: 0xB32A859C1023545bbc4Ac44D5A3150A8bCaB5f6B'),
            OutlinedButton.icon(
              onPressed: () {
                if (_address != null) {
                  Clipboard.setData(ClipboardData(text: _address!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wallet address copied to clipboard'),
                    ),
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Wallet address copied to clipboard'),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Wallet Address'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Balance',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_balance} ${walletProvider.selectedNetwork.symbol}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateBalance,
              child: Text('Refresh Balance'),
            ),
            SizedBox(height: 16),
            SendTransactionWidget(walletService: _walletService),
          ],
        ),
      ),
    );
  }
}

class SendTransactionWidget extends StatefulWidget {
  final WalletService walletService;

  SendTransactionWidget({required this.walletService});

  @override
  _SendTransactionWidgetState createState() => _SendTransactionWidgetState();
}

class _SendTransactionWidgetState extends State<SendTransactionWidget> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendTransaction() async {
    setState(() => _isSending = true);
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      final txHash = await widget.walletService.sendTransaction(
        privateKey: provider.privateKey!,
        to: _toController.text,
        amount: double.parse(_amountController.text),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction sent: $txHash')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _toController,
          decoration: InputDecoration(labelText: 'To Address'),
        ),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(labelText: 'Amount (ETH)'),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isSending ? null : _sendTransaction,
          child: _isSending
              ? CircularProgressIndicator()
              : Text('Send Transaction'),
        ),
      ],
    );
  }
}
