import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { zeroAddress, chains, vaultFees } from "../../helpers/constants";

describe('VaultBase', () => {
    async function deployVaultBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avax', 'TJ_AVAX_USDC', owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const vault = await upgrades.deployProxy(Vault, initArgs);
        await vault.deployed();

        return {vault, owner, otherAccount};
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);

            // Run
            const treasury = await vault.treasury();
            const router = await vault.router();
            const stablecoin = await vault.stablecoin();
            const entranceFeeFactor = await vault.entranceFeeFactor();
            const withdrawFeeFactor = await vault.withdrawFeeFactor();
            const defaultSlippageFactor = await vault.defaultSlippageFactor();
            const name = await vault.name();
            const symbol = await vault.symbol();
            const decimals = await vault.decimals();

            // Test
            expect(treasury).to.equal(chains.avax.admin.treasury);
            expect(router).to.equal(chains.avax.infra.uniRouterAddress);
            expect(stablecoin).to.equal(chains.avax.tokens.usdc);
            expect(entranceFeeFactor).to.equal(vaultFees.entranceFeeFactor);
            expect(withdrawFeeFactor).to.equal(vaultFees.withdrawFeeFactor);
            expect(defaultSlippageFactor).to.equal(9900);
            expect(name).to.equal('ZOR LP Vault');
            expect(symbol).to.equal('ZLPV');
            expect(decimals).to.equal(18);
        });
    });

    describe('Setters', () => {
        it('Should set the treasury', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);
            const newTreasury = ethers.Wallet.createRandom().address;

            // Run
            await vault.setTreasury(newTreasury);
            
            // Test
            expect(await vault.treasury()).to.equal(newTreasury);
        });

        it('Should set fee parameters', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);
            const newEntranceFee = 9500;
            const newWithdawalFee = 9700;

            // Run
            await vault.setFeeParams(newEntranceFee, newWithdawalFee);
            
            // Test
            expect(await vault.entranceFeeFactor()).to.equal(newEntranceFee);
            expect(await vault.withdrawFeeFactor()).to.equal(newWithdawalFee);
        });

        it('Should set the default slippage factor', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);
            const newSlippage = 9999;

            // Run
            await vault.setDefaultSlippageFactor(newSlippage);
            
            // Test
            expect(await vault.defaultSlippageFactor()).to.equal(newSlippage);
        });

        it('Should set swap paths', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);
            const newSwapPath = []; 
            for (let i=0; i<2; i++) {
                newSwapPath.push(ethers.Wallet.createRandom().address);

            }

            // Run
            await vault.setSwapPaths(newSwapPath);
            
            // Test
            expect(await vault.swapPaths(newSwapPath[0], newSwapPath[1], 0)).to.equal(newSwapPath[0]);
            expect(await vault.swapPaths(newSwapPath[0], newSwapPath[1], 1)).to.equal(newSwapPath[1]);
        });

        it('Should set a price feed for a token', async () => {
            // Prep
            const {vault, owner} = await loadFixture(deployVaultBaseFixture);
            const dummyToken = ethers.Wallet.createRandom().address;
            const newPriceFeed = ethers.Wallet.createRandom().address;

            // Run
            await vault.setPriceFeed(dummyToken, newPriceFeed);
            
            // Test
            expect(await vault.priceFeeds(dummyToken)).to.equal(newPriceFeed);
        });
    });
});