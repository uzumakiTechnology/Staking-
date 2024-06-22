
import "@matterlabs/hardhat-zksync-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";
import "@nomiclabs/hardhat-ethers";
import "@matterlabs/hardhat-zksync-node";



module.exports = {
  zksolc: {
    version: "1.3.13",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "zkSyncTestnet",

  networks: {
    zkSyncTestnet: {
      url: "https://testnet.era.zksync.dev",
        ethNetwork: "goerli",
        zksync: true,
      verifyURL:
        "https://zksync2-testnet-explorer.zksync.dev/contract_verification",
      accounts:['c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6']
    },
  },
  etherscan: {
    apiKey: "J337XBMXMJ2U32HHUVINKYDQH6FKTXDAIQ",
  },
  solidity: {
    version: "0.8.20",
  },
};

