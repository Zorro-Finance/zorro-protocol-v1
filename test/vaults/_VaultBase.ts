import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from '../../helpers/deployments/vaults/VaultUniswapV2/deployment';
import { chains, vaultFees } from "../../helpers/constants";

describe('VaultBase', () => {
    async function deployVaultBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avalanche', owner.address, owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('VaultUniswapV2');
        const vault = await upgrades.deployProxy(
            Vault,
            initArgs,
            {
                kind: 'uups',
            }
        );
        
        await vault.deployed();

        return { vault, owner, otherAccount };
    }

    describe('Deployment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);

            // Run
            const treasury = await vault.treasury();
            const router = await vault.router();
            const stablecoin = await vault.stablecoin();
            const entranceFeeFactor = await vault.entranceFeeFactor();
            const withdrawFeeFactor = await vault.withdrawFeeFactor();
            const defaultSlippageFactor = await vault.defaultSlippageFactor();

            // Test
            expect(treasury).to.equal(chains.avalanche!.admin.multiSigOwner);
            expect(router).to.equal(chains.avalanche!.infra.uniRouterAddress);
            expect(stablecoin).to.equal(chains.avalanche!.tokens.usdc);
            expect(entranceFeeFactor).to.equal(vaultFees.entranceFeeFactor);
            expect(withdrawFeeFactor).to.equal(vaultFees.withdrawFeeFactor);
            expect(defaultSlippageFactor).to.equal(9900);
        });
    });

    describe('Setters', () => {
        it('Should set the treasury', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const newTreasury = ethers.Wallet.createRandom().address;

            // Run
            await vault.setTreasury(newTreasury);

            // Test
            expect(await vault.treasury()).to.equal(newTreasury);
        });

        it('Should set fee parameters', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
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
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const newSlippage = 9999;

            // Run
            await vault.setDefaultSlippageFactor(newSlippage);

            // Test
            expect(await vault.defaultSlippageFactor()).to.equal(newSlippage);
        });

        it('Should set a price feed for a token', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const dummyToken = ethers.Wallet.createRandom().address;
            const newPriceFeed = ethers.Wallet.createRandom().address;

            // Run
            await vault.setPriceFeed(dummyToken, newPriceFeed);

            // Test
            expect(await vault.priceFeeds(dummyToken)).to.equal(newPriceFeed);
        });

        it('Should set the gov address', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const dummyGov = ethers.Wallet.createRandom().address;

            // Run
            await vault.setGov(dummyGov);

            // Test
            expect(await vault.gov()).to.equal(dummyGov);
        });
    });
});