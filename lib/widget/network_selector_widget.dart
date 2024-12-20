// network_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web_3wallet/blockchain_config.dart';
import 'package:web_3wallet/wallet_provider.dart';

class NetworkSelectorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (walletProvider.isConnecting)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        PopupMenuButton<String>(
          child: Chip(
            avatar: Icon(
              Icons.router,
              color: walletProvider.isConnected ? Colors.green : Colors.red,
            ),
            label: Text(walletProvider.selectedNetwork.name),
          ),
          itemBuilder: (context) {
            return BlockchainConfig.networks.entries.map((entry) {
              return PopupMenuItem(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: entry.key == walletProvider.currentNetwork
                          ? Colors.green
                          : Colors.grey,
                      size: 12,
                    ),
                    SizedBox(width: 8),
                    Text(entry.value.name),
                  ],
                ),
              );
            }).toList();
          },
          onSelected: (networkKey) async {
            await walletProvider.switchNetwork(networkKey);
          },
        ),
      ],
    );
  }
}

// send_transaction_screen.dart
class SendTransactionScreen extends StatefulWidget {
  @override
  _SendTransactionScreenState createState() => _SendTransactionScreenState();
}

class _SendTransactionScreenState extends State<SendTransactionScreen> {
  final _toController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Send ${walletProvider.selectedNetwork.symbol}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _toController,
              decoration: InputDecoration(
                labelText: 'To Address',
                hintText: '0x...',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: walletProvider.selectedNetwork.symbol,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSending
                  ? null
                  : () async {
                      setState(() => _isSending = true);
                      try {
                        final txHash = await walletProvider.sendTransaction(
                          to: _toController.text,
                          amount: double.parse(_amountController.text),
                          gasPrice: null, // Add gas estimation
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transaction sent: $txHash')),
                        );
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      } finally {
                        setState(() => _isSending = false);
                      }
                    },
              child: _isSending ? CircularProgressIndicator() : Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  walletProvider.isConnected ? Icons.check_circle : Icons.error,
                  color: walletProvider.isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Network Status: ${walletProvider.isConnected ? 'Connected' : 'Disconnected'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (walletProvider.connectionError != null) ...[
              SizedBox(height: 8),
              Text(
                walletProvider.connectionError!,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => walletProvider.initializeWeb3(),
                child: Text('Retry Connection'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ImportWalletWidget extends StatefulWidget {
  @override
  _ImportWalletWidgetState createState() => _ImportWalletWidgetState();
}

class _ImportWalletWidgetState extends State<ImportWalletWidget> {
  final _privateKeyController = TextEditingController();
  bool _isLoading = false;
  bool _walletImported = false;
  String? _walletAddress;
  String? _mnemonic;
  double? _balance;

  Future<void> _importAndFetchWalletDetails() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<WalletProvider>(context, listen: false);

      // Import wallet
      await provider.importWalletFromPrivateKey(_privateKeyController.text);

      // Get wallet details
      _walletAddress = provider.currentAddress?.hexEip55;
      _balance = provider.balance;

      setState(() {
        _walletImported = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing wallet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildWalletDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                _buildDetailRow('Wallet Address:', _walletAddress ?? 'N/A'),
                SizedBox(height: 8),
                _buildDetailRow(
                  'Private Key:',
                  '${_privateKeyController.text.substring(0, 6)}...${_privateKeyController.text.substring(_privateKeyController.text.length - 4)}',
                ),
                SizedBox(height: 8),
                _buildDetailRow(
                  'Balance:',
                  '${_balance?.toStringAsFixed(6) ?? '0'} ${Provider.of<WalletProvider>(context).selectedNetwork.symbol}',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _walletAddress!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Address copied to clipboard')),
                );
              },
              icon: Icon(Icons.copy),
              label: Text('Copy Address'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final provider =
                    Provider.of<WalletProvider>(context, listen: false);
                await provider.updateBalance();
                setState(() {
                  _balance = provider.balance;
                });
              },
              icon: Icon(Icons.refresh),
              label: Text('Refresh Balance'),
            ),
          ],
        ),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Done'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Import Wallet'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_walletImported) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter Private Key',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _privateKeyController,
                        decoration: InputDecoration(
                          labelText: 'Private Key',
                          hintText: 'Enter your private key',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            _isLoading ? null : _importAndFetchWalletDetails,
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Import Wallet'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              _buildWalletDetails(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _privateKeyController.dispose();
    super.dispose();
  }
}
