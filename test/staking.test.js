const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const {Wallet, Provider, Contract, utils} = require("zksync-web3")
const {Deployer} = require("@matterlabs/hardhat-zksync-deploy")
const {HardhatRuntimeEnvironment} = require("hardhat/types")
const hre = require("hardhat");

describe("Pool Creation", function () {
  let provider = new Provider("https://testnet.era.zksync.dev", 280);
  wallet = new Wallet("c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6", provider);

  let deployer = new Deployer(hre, wallet);

  let StakingContract, staking, USDC, USDT, owner, addr1, addr2;

  let reward_token_address = "0x4cD67E306ecaD1Cac71a2BD4abC1A4c22B55d331";
  let WETH = "0x20b28B1e4665FFf290650586ad76E977EAb90c5D";
  USDT = "0xDf9acc0a00Ae6Ec5eBc8D219d12A0157e7F18A68";
  USDC = "0x400de4eC1f3B697aAb2f60dFEb089859c85db58d";
  let ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // deploy the staking contract
    const deployer = new Deployer(hre, wallet);
    const artifact = await deployer.loadArtifact("Staking");
    StakingContract = await deployer.deploy(artifact, [
      "0xDCeA30E35Eb995Bc43DF40B9e43262afBc60795f",
      "0xaF441a4825Bd8D25ee1BF5CfDFDBb4738404F83f",
    ]);
  });

  it("Should allow successful pool creation WETH", async function(){
    const rewardAmount = ethers.utils.parseEther("1000");    
    await expect(StakingContract.createPool(ETH, rewardAmount))
        .to.emit(StakingContract, "PoolCreated")
        .withArgs(ETH, rewardAmount, 0);
  });
  it("Should prevent duplicate pool creation", async function(){
    const ethers = require("hardhat").ethers;
    const rewardAmount = ethers.utils.parseEther("1000");
    await StakingContract.createPool(ETH, rewardAmount);

    await expect(StakingContract.createPool(ETH, rewardAmount))
    .to.be.revertedWith("Pool already exist for this token");
  });

  it("Should revert pool creation with invalud token address", async function(){
    const invalidTokenAddress = ethers.constants.AddressZero;
    const rewardAmount = ethers.utils.parseEther("1000");

    await expect(StakingContract.createPool(invalidTokenAddress, rewardAmount))
        .to.be.revertedWith("Staking token is Invalid, must choose between ETH, USDC, USDT");
  });

  it("Should revert pool creation with zero reward amount", async function(){
    const rewardAmount = ethers.utils.parseEther("0");

    await expect(StakingContract.createPool(ETH, rewardAmount))
        .to.be.revertedWith("Reward amount transfer must greater than zero");
  });
});

describe.only("Withdraw", function () {
  let provider = new Provider("https://testnet.era.zksync.dev", 280);
  wallet = new Wallet("c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6", provider);
  let deployer = new Deployer(hre, wallet);


  let Staking, StakingToken, staking, stakingToken, USDC, USDT, owner, addr1, addr2;
  let reward_token_address = "0x4cD67E306ecaD1Cac71a2BD4abC1A4c22B55d331";
  let WETH = "0x20b28B1e4665FFf290650586ad76E977EAb90c5D";
  USDT = "0xDf9acc0a00Ae6Ec5eBc8D219d12A0157e7F18A68";
  USDC = "0x400de4eC1f3B697aAb2f60dFEb089859c85db58d";
  let ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";


  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const deployer = new Deployer(hre, wallet);

    const artifactERC20 = await deployer.loadArtifact("ERC20Token");
    stakingToken = await deployer.deploy(artifactERC20,[
      "USDT",
      "USDT"
    ]);

    // Deploy the Staking contract
    const artifact = await deployer.loadArtifact("Staking");
    StakingContract = await deployer.deploy(artifact, [
            "0xDCeA30E35Eb995Bc43DF40B9e43262afBc60795f",
            "0xaF441a4825Bd8D25ee1BF5CfDFDBb4738404F83f",
          ]);
    // Transfer some tokens to the Staking contract to simulate rewards
    // await USDT.transfer(StakingContract.address, 500000);

    // Create a pool with WETH token
    const rewardAmount = 1000;
    await StakingContract.createPool(ETH, rewardAmount);
  });

  it("Should allow user to successfully withdraw initial deposit", async function () {
    // Connect to the staking contract as addr1
    const stakingAsAddr1 = StakingContract.connect(addr1);

    // Approve the staking contract to spend addr1's tokens
    await stakingToken.connect(addr1).approve(StakingContract.address,100);

    // Deposit tokens into the pool
    const poolId = 0;
    const depositAmount = 100;
    await stakingAsAddr1.deposit(depositAmount, 30, poolId);

    // Wait for the deposit period to pass (mock or fast-forward time as needed)

    // Withdraw tokens
    const withdrawAmount = depositAmount;
    await expect(stakingAsAddr1.withdraw(0))
      .to.emit(staking, "Withdrawn")
      .withArgs(addr1.address, withdrawAmount, 0, poolId);

  });
});
