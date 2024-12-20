// blockchain_config.dart
class BlockchainNetwork {
  final String name;
  final String rpcUrl;
  final int chainId;
  final String symbol;
  final String blockExplorerUrl;

  BlockchainNetwork({
    required this.name,
    required this.rpcUrl,
    required this.chainId,
    required this.symbol,
    required this.blockExplorerUrl,
  });
}

class BlockchainConfig {
  static final networks = {
    'ethereum': BlockchainNetwork(
      name: 'Ethereum',
      rpcUrl: 'https://eth.llamarpc.com',
      chainId: 1,
      symbol: 'ETH',
      blockExplorerUrl: 'https://etherscan.io',
    ),
    'bsc': BlockchainNetwork(
      name: 'Binance Smart Chain',
      rpcUrl: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      symbol: 'BNB',
      blockExplorerUrl: 'https://bscscan.com',
    ),
    'polygon': BlockchainNetwork(
      name: 'Polygon',
      rpcUrl: 'https://polygon-rpc.com',
      chainId: 137,
      symbol: 'MATIC',
      blockExplorerUrl: 'https://polygonscan.com',
    ),
    'goerli': BlockchainNetwork(
      name: 'Goerli Testnet',
      rpcUrl: 'https://goerli.infura.io/v3/YOUR_INFURA_KEY',
      chainId: 5,
      symbol: 'ETH',
      blockExplorerUrl: 'https://goerli.etherscan.io',
    ),
    'BC Hyper': BlockchainNetwork(
      name: 'BC Hyper',
      rpcUrl: 'https://rpc.bchscan.io',
      chainId: 6060,
      symbol: 'VTCN',
      blockExplorerUrl: 'https://testnet.bchscan.io/',
    ),
  };
}
