import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from "../../helpers/deployments/controllers/ControllerXChain/deployment";
import { chains } from "../../helpers/constants";

describe('ControllerXChain', () => {
    async function deployControllerXChainFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avax', owner.address);

        // Get contract factory
        const Controller = await ethers.getContractFactory('ControllerXChain');
        const controller = await upgrades.deployProxy(Controller, initArgs);
        await controller.deployed();

        return {controller, owner, otherAccount};
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const {controller, owner} = await loadFixture(deployControllerXChainFixture);

            // Run
            const layerZeroEndpoint = await controller.layerZeroEndpoint();
            const stargateRouter = await controller.stargateRouter();
            const currentChain = await controller.currentChain();
            const sgPoolId = await controller.sgPoolId();

            const router = await controller.router();
            const stablecoin = await controller.stablecoin();
            const stablecoinPriceFeed = await controller.stablecoinPriceFeed();
            const _owner = await controller.owner();

            // Test
            expect(layerZeroEndpoint).to.equal(chains.avax.infra.layerZeroEndpoint);
            expect(stargateRouter).to.equal(chains.avax.infra.stargateRouter);
            expect(currentChain).to.equal(chains.avax.xChain.lzChainId);
            expect(sgPoolId).to.equal(chains.avax.xChain.sgPoolId);
            
            expect(router).to.equal(chains.avax.infra.uniRouterAddress);
            expect(stablecoin).to.equal(chains.avax.tokens.usdc);
            expect(stablecoinPriceFeed).to.equal(chains.avax.priceFeeds.usdc);
            expect(_owner).to.equal(owner.address);
        });
    });

    describe('Setters', () => {
        it('Should set key cross chain parameters', async () => {
            // Prep
            const {controller, owner} = await loadFixture(deployControllerXChainFixture);
            const newLZEndpoint = ethers.Wallet.createRandom().address;
            const newSGRouter = ethers.Wallet.createRandom().address;
            const newChainId = 24;
            const newSGPoolId = 66;

            // Run
            await controller.setKeyXChainParams(
                newLZEndpoint,
                newSGRouter,
                newChainId,
                newSGPoolId
            );

            // Test
            expect(await controller.layerZeroEndpoint()).to.equal(newLZEndpoint);
            expect(await controller.stargateRouter()).to.equal(newSGRouter);
            expect(await controller.currentChain()).to.equal(newChainId);
            expect(await controller.sgPoolId()).to.equal(newSGPoolId);
        });

        it('Should set swap parameters', async () => {
            // Prep
            const {controller, owner} = await loadFixture(deployControllerXChainFixture);
            const newRouter = ethers.Wallet.createRandom().address;
            const newStablecoin = ethers.Wallet.createRandom().address;
            const newStablecoinPriceFeed = ethers.Wallet.createRandom().address;

            // Run
            await controller.setSwapParams(
                newRouter,
                newStablecoin,
                newStablecoinPriceFeed
            );

            // Test
            expect(await controller.router()).to.equal(newRouter);
            expect(await controller.stablecoin()).to.equal(newStablecoin);
            expect(await controller.stablecoinPriceFeed()).to.equal(newStablecoinPriceFeed);
        });
    });

    describe('Deposits', () => {
        xit('Should ENCODE a cross chain deposit request', async () => {

        });

        xit('Should get a QUOTE for a cross chain deposit', async () => {

        });

        xit('Should SEND a cross chain deposit request', async () => {

        });

        xit('Should RECEIVE a cross chain deposit request', async () => {

        });
    });

    describe('Withdrawals', () => {
        xit('Should ENCODE a cross chain withdrawal request', async () => {

        });

        xit('Should get a QUOTE for a cross chain withdrawal', async () => {

        });

        xit('Should SEND a cross chain withdrawal request', async () => {

        });

        xit('Should RECEIVE a cross chain withdrawal request', async () => {

        });
    });
});