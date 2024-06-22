import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
const PRIVATE_KEY =
  "c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6";
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Marketplace contract`);

  const wallet = new Wallet(PRIVATE_KEY);

  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("Marketplace");


  // const StakingContract = await deployer.deploy(artifact, [
  //   "0xDCeA30E35Eb995Bc43DF40B9e43262afBc60795f",
  //   "0xABE326Ec882388da5eafb6BfBAD95872640E2484",
  // ]);

  const MarketplaceContract = await deployer.deploy(artifact);


  // Show the contract info.
  const contractAddress = MarketplaceContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}
