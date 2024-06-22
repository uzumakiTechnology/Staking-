const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const {Wallet, Provider, Contract, utils} = require("zksync-web3")
const {Deployer} = require("@matterlabs/hardhat-zksync-deploy")
const {HardhatRuntimeEnvironment} = require("hardhat/types")
const hre = require("hardhat");


describe("Marketplace", function () {
    let provider = new Provider("https://testnet.era.zksync.dev", 280)
    let wallet = new Wallet("c2d5473c1a7263d4c36f2a426845e62c2869aea11143a0463b8648010d954ad6", provider)

    let deployer = new Deployer(hre, wallet);
    let Marketplace;
    let marketplace;
    let owner;
    let addr1;
    let addr2;

    const tokenURI = "https://tokenURI.com";
    const listingPrice = ethers.utils.parseEther("0.0025");

    beforeEach(async function () {
        let deployer = new Deployer(hre, wallet);
        const artifact = await deployer.loadArtifact("Marketplace");

        Marketplace = await deployer.deploy(artifact)
        await Marketplace.deployed();

        [owner, addr1, addr2] = await ethers.getSigners();

    });

    it("Should create a new token", async function () {
        await marketplace.createToken(tokenURI, listingPrice);

        const tokenURIStored = await marketplace.tokenURI(1);
        expect(tokenURIStored).to.equal(tokenURI);
    });

    it("Should get the listing price", async function () {
        const retrievedListingPrice = await marketplace.getListingPrice();
        expect(retrievedListingPrice).to.equal(listingPrice);
    });

    // Add more test cases for other functions as needed
});