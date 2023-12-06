import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
const PRIVATE_KEY =
  "c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6";
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Staking contract`);

  const wallet = new Wallet(PRIVATE_KEY);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("Staking");

  // Estimate contract deployment fee
  //   const deploymentFee = await deployer.estimateDeployFee(artifact, [
  //     "SOBA",
  //     "SB",
  //   ]);
  //   console.log(deploymentFee);

  const StakingContract = await deployer.deploy(artifact, [
    "0xDCeA30E35Eb995Bc43DF40B9e43262afBc60795f",
    "0xaF441a4825Bd8D25ee1BF5CfDFDBb4738404F83f",
  ]);

  //   const ERC20Contract = await deployer.deploy(artifact, ["KEVIN", "K"]);

  // Show the contract info.
  const contractAddress = StakingContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
}
