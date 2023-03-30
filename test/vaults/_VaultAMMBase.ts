import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from '../../helpers/deployments/VaultAMM/TraderJoe/deployment';
import { zeroAddress, chains } from "../../helpers/constants";
import { BigNumber } from "ethers";

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avax', 'TJ_AVAX_USDC', owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const vault = await upgrades.deployProxy(Vault, initArgs);
        await vault.deployed();

        return { vault, owner, otherAccount };
    }

    async function getAssets(amountETH: BigNumber) {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();
        const provider = ethers.provider;

        // Get LP pair
        const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);

        // Get router
        const router = await ethers.getContractAt('IJoeRouter02', chains.avax.infra.uniRouterAddress);

        // Get min USDC out and account for some slippage 
        const path = [chains.avax.tokens.wavax, chains.avax.tokens.usdc];
        const amountsOut = await router.getAmountsOut(
            amountETH,
            path
        );
        const minAmountUSDC = amountsOut[amountsOut.length-1].mul(95).div(100);

        // Swap to get USDC
        await router.swapExactAVAXForTokens(
            minAmountUSDC,
            path,
            owner.address,
            (await time.latest()) + 120,
            { value: amountETH }
        );

        // Get USDC balance
        const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avax.tokens.usdc);
        const balUSDC = await usdc.balanceOf(owner.address);

        // Add liquidity, while preserving half of the USDC
        const amountUSDCIn = balUSDC.div(2);
        const amountAVAXIn = amountUSDCIn.mul(amountETH).div(amountsOut[amountsOut.length-1]);
        await usdc.approve(router.address, amountUSDCIn);
        await router.addLiquidityAVAX(
            chains.avax.tokens.usdc,
            amountUSDCIn,
            0,
            0,
            owner.address,
            (await time.latest()) + 120,
            { value: amountAVAXIn }
        );
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Run
            const asset = await vault.asset();
            const token0 = await vault.token0();
            const token1 = await vault.token1();
            const farmContract = await vault.farmContract();
            const rewardsToken = await vault.rewardsToken();
            const isFarmable = await vault.isFarmable();
            const pid = await vault.pid();
            const pool = await vault.pool();

            // Check swap paths
            expect(await vault.swapPathLength(chains.avax.tokens.wavax, chains.avax.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.usdc, chains.avax.tokens.usdc)).to.equal(0);
            expect(await vault.swapPathLength(chains.avax.tokens.wavax, chains.avax.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.joe, chains.avax.tokens.wavax)).to.equal(2);
            expect(await vault.swapPathLength(chains.avax.tokens.joe, chains.avax.tokens.usdc)).to.equal(2);

            // Check price feeds
            expect(await vault.priceFeeds(chains.avax.tokens.wavax)).to.equal(chains.avax.priceFeeds.avax);
            expect(await vault.priceFeeds(chains.avax.tokens.usdc)).to.equal(chains.avax.priceFeeds.usdc);
            expect(await vault.priceFeeds(chains.avax.tokens.joe)).to.equal(chains.avax.priceFeeds.joe);

            // Test
            expect(asset).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            expect(token0).to.equal(chains.avax.tokens.wavax);
            expect(token1).to.equal(chains.avax.tokens.usdc);
            expect(farmContract).to.equal(chains.avax.protocols.traderjoe.masterChef);
            expect(rewardsToken).to.equal(chains.avax.tokens.joe);
            expect(isFarmable).to.equal(true);
            expect(pid).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid);
            expect(pool).to.equal(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
        });
    });

    describe('Setters', () => {
        it('Should set key tokens and contract addresses', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            const newAsset = ethers.Wallet.createRandom().address;
            const newToken0 = ethers.Wallet.createRandom().address;
            const newToken1 = ethers.Wallet.createRandom().address;
            const newPool = ethers.Wallet.createRandom().address;

            // Run
            await vault.setTokens(newAsset, newToken0, newToken1, newPool);

            // Test
            // TODO: Change these to actual values
            expect(await vault.asset()).to.equal(newAsset);
            expect(await vault.token0()).to.equal(newToken0);
            expect(await vault.token1()).to.equal(newToken1);
            expect(await vault.pool()).to.equal(newPool);
        });

        it('Should set farm parameters', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            const newFarmContract = ethers.Wallet.createRandom().address;
            const newRewardstoken = ethers.Wallet.createRandom().address;
            const newPid = 1;

            // Run
            await vault.setFarmParams(
                false,
                newFarmContract,
                newRewardstoken,
                newPid
            );

            // Test
            expect(await vault.isFarmable()).to.equal(false);
            expect(await vault.farmContract()).to.equal(newFarmContract);
            expect(await vault.rewardsToken()).to.equal(newRewardstoken);
            expect(await vault.pid()).to.equal(newPid);
        });
    });

    describe('Deposits', () => {
        it('Deposits main asset token', async () => {
            // Prep
            
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Test

            /*
            - I expect shares to be added, proportional to the size of the pool
            - I expect the total shares to be incremented by the above amount, accounting for fees
            - I expect the principal debt to be incremented by the Want amount deposited
            - I expect the want token to be farmed (and at the appropriate amount)
            - I expect the current want equity to be correct
            */

            // TODO: Test assertions
        });

        it('Deposits asset token twice', async () => {
            // Prep
            
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP.mul(2));
            // Deposit once
            await vault.deposit(amountLP);
            // Deposit twice
            await vault.deposit(amountLP);

            // Test
            // TODO: Assertions
        });

        it('Deposits USD', async () => {
            // Prep
            
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avax.tokens.usdc);
            const balUSDC = await usdc.balanceOf(owner.address);
            const amountUSDC = balUSDC.div(10);

            // Run
            await usdc.approve(vault.address, amountUSDC);
            await vault.depositUSD(amountUSDC, 9900);

            // Test
            // TODO: Assertions
        });
    });

    describe('Withdrawals', () => {
        xit('Withdraws main asset token (full withdrawal)', async () => {

        });

        xit('Withdraws main asset token twice (partial withdrawals)', async () => {

        });

        xit('Withdraws to USD', async () => {

        });
    });

    describe('Earnings', () => {
        it('Compounds (reinvests) farm rewards', async () => {
            // Prep

            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avax.protocols.traderjoe.masterChef);

            // Run

            // Deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Advance blocks (need many to produce enough rewards)
            for (let i=0; i<100; i++) {
                await masterChef.updatePool(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid);
            }

            // Earn
            await vault.earn(9000); // 10% slippage. WARNING: Because of low rewards after time elapsed in test, test could fail if slippage set incorrectly

            // Test
            // TODO: Assertions
        });
    });

    describe('Utilities', () => {
        it('Should calculuate amount farmed', async () => {
            // Prep
            
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avax.protocols.traderjoe.masterChef);

            // Run

            // Deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Advance a few blocks and update masterchef pool rewards
            for (let i=0; i<5; i++) {
                await masterChef.updatePool(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid);
            }

            // Test
            expect(await vault.amountFarmed()).to.equal(amountLP);
        });

        it('Should calculuate pending rewards farmed', async () => {
            // Prep
            
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avax.protocols.traderjoe.masterChef);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avax.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);
            // Advance a few blocks and update masterchef pool rewards
            for (let i=0; i<5; i++) {
                await masterChef.updatePool(chains.avax.protocols.traderjoe.pools.AVAX_USDC.pid);
            }

            // Test
            expect(await vault.pendingRewards()).to.be.greaterThan(0);
        });
    });
});