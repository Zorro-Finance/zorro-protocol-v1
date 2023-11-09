import { time, loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from '../../helpers/deployments/vaults/VaultUniswapV2/deployment';
import { chains } from "../../helpers/constants";
import { BigNumber } from "ethers";
import { getPermitSignature, getTransactPermitSignature } from "../../helpers/tests/metatx";

describe('VaultUniswapV2Base', () => {
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

        // Set swap paths
        const token0 = chains.avalanche!.tokens.wavax;
        const token1 = chains.avalanche!.tokens.usdc;
        const usdc = chains.avalanche!.tokens.usdc;

        await vault.setSwapPaths([token0, usdc]);
        await vault.setSwapPaths([token1, usdc]);
        await vault.setSwapPaths([usdc, token1]);
        await vault.setSwapPaths([usdc, token0]);

        return { vault, owner, otherAccount };
    }

    async function getAssets(amountETH: BigNumber) {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get LP pair
        const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);

        // Get router
        const router = await ethers.getContractAt('IJoeRouter02', chains.avalanche!.infra.uniRouterAddress);

        // Get min USDC out and account for some slippage 
        const path = [chains.avalanche!.tokens.wavax, chains.avalanche!.tokens.usdc];
        const amountsOut = await router.getAmountsOut(
            amountETH,
            path
        );
        const minAmountUSDC = amountsOut[amountsOut.length - 1].mul(95).div(100);

        // Swap to get USDC
        await router.swapExactAVAXForTokens(
            minAmountUSDC,
            path,
            owner.address,
            (await time.latest()) + 120,
            { value: amountETH }
        );

        // Get USDC balance
        const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
        const balUSDC = await usdc.balanceOf(owner.address);

        // Add liquidity, while preserving half of the USDC
        const amountUSDCIn = balUSDC.div(2);
        const amountAVAXIn = amountUSDCIn.mul(amountETH).div(amountsOut[amountsOut.length - 1]);
        await usdc.approve(router.address, amountUSDCIn);
        await router.addLiquidityAVAX(
            chains.avalanche!.tokens.usdc,
            amountUSDCIn,
            0,
            0,
            owner.address,
            (await time.latest()) + 120,
            { value: amountAVAXIn }
        );
    }

    function getVaultData() {
        const {pool} = chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC;
        const token0 = chains.avalanche!.tokens.wavax;
        const token1 = chains.avalanche!.tokens.usdc;

        const abiCoder = ethers.utils.defaultAbiCoder;
        return abiCoder.encode(
            ['address', 'address', 'address'],
            [pool, token0, token1]
        );
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);

            // Run

            // Test
            expect(await vault.priceFeeds(chains.avalanche!.tokens.wavax)).to.equal(chains.avalanche!.priceFeeds.avax);
            expect(await vault.priceFeeds(chains.avalanche!.tokens.usdc)).to.equal(chains.avalanche!.priceFeeds.usdc);
        });
    });

    describe('Deposits', () => {
        it('Deposits USD', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const pool = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balUSDC = await usdc.balanceOf(owner.address);
            const amountUSDC = balUSDC.div(10);

            // Prep data payload
            const data = getVaultData();
            
            // Run
            await usdc.approve(vault.address, amountUSDC);
            await vault.depositUSD(amountUSDC, 9900, owner.address, owner.address, data);

            const balLPToken = await pool.balanceOf(owner.address);
            const balTreasuryUSDC = await usdc.balanceOf(chains.avalanche!.admin.multiSigOwner);
            
            // Test
            expect(balLPToken).to.be.greaterThan(0);
            expect(balTreasuryUSDC).to.be.greaterThan(0);
        });
    });

    describe('Withdrawals', () => {
        it('Withdraws to USD (full withdrawal)', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const balUSDCInitial = await usdc.balanceOf(owner.address);
            const balLPInitial = await pair.balanceOf(owner.address);
            
            // Make deposit
            const data = getVaultData();
            await usdc.approve(vault.address, balUSDCInitial);
            await vault.depositUSD(balUSDCInitial, 9900, owner.address, owner.address, data);
            const balLPNew = await pair.balanceOf(owner.address);
            const balLPAdded = balLPNew.sub(balLPInitial);

            // Run

            // Make withdrawal
            await pair.approve(vault.address, balLPAdded);
            await vault.withdrawUSD(balLPAdded, 9900, owner.address, owner.address, data);

            // Test

            // Withdraws all shares, net of fees
            expect(await pair.balanceOf(owner.address)).to.be.approximately(balLPInitial, 1000);
            expect(await usdc.balanceOf(owner.address)).to.be.approximately(balUSDCInitial.mul(98).div(100), 500000);
        });

        it('Withdraws to USD (partial withdrawal)', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const balUSDCInitial = await usdc.balanceOf(owner.address);
            const balLPInitial = await pair.balanceOf(owner.address);

            // Make deposit
            const data = getVaultData();
            await usdc.approve(vault.address, balUSDCInitial);
            await vault.depositUSD(balUSDCInitial, 9900, owner.address, owner.address, data);
            const balLPNew = await pair.balanceOf(owner.address);
            const balLPAdded = balLPNew.sub(balLPInitial);

            // Run

            // Make withdrawal
            await pair.approve(vault.address, balLPAdded);
            await vault.withdrawUSD(balLPAdded.div(10), 9900, owner.address, owner.address, data);

            // Test

            // Withdraws some tokens
            expect(await pair.balanceOf(owner.address)).to.be.greaterThan(balLPInitial);
            expect(await usdc.balanceOf(owner.address)).to.be.greaterThan(0);
        });
    });

    describe('Gasless', () => {
        it('Deposits USD as a meta transaction', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const usdcPermit = await ethers.getContractAt('IERC20PermitUpgradeable', chains.avalanche!.tokens.usdc);
            const usdcERC20 = await ethers.getContractAt('ERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const abiUSDC = [
                ...usdcPermit.interface.format(),
                ...usdcERC20.interface.format(),
            ];
            const usdc = await ethers.getContractAt(abiUSDC, chains.avalanche!.tokens.usdc);
            const balUSDC = await usdc.balanceOf(owner.address);
            const amountUSDC = balUSDC.div(10);
            const maxMarketMovement = 9900;

            // Get wallet
            const signerProvider = owner.provider!;
            const wallet0PK = ethers.Wallet.createRandom().privateKey;
            const wallet0 = new ethers.Wallet(wallet0PK, signerProvider);

            // Transfer USD to wallet for signature
            await usdc.transfer(wallet0.address, amountUSDC);

            // Run

            // Get permit signature from wallet
            const { sig, deadline } = await getPermitSignature(
                wallet0,
                vault.address,
                usdc,
                amountUSDC,
                '2'
            );
            // Get permit for allowance
            await usdc.permit(
                wallet0.address,
                vault.address,
                amountUSDC,
                deadline,
                sig.v,
                sig.r,
                sig.s
            );

            // Get signature for deposit
            const data = getVaultData();
            const metaTxRes = await getTransactPermitSignature(
                wallet0,
                vault,
                'ZVault UniswapV2',
                amountUSDC,
                maxMarketMovement,
                'deposit',
                data
            );
            // Make deposit meta transaction
            const tx = await vault.transactUSDWithPermit(
                wallet0.address,
                amountUSDC,
                maxMarketMovement,
                0, // Deposit
                metaTxRes.deadline,
                data,
                {
                    v: metaTxRes.sig.v,
                    r: metaTxRes.sig.r,
                    s: metaTxRes.sig.s,
                }
            );

            // Test

            // Assert that earnings ocurred on the second withdrawal
            await expect(tx).to.emit(vault, 'DepositUSD');
        });

        it('Withdraws shares to USD as a meta transaction', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const maxMarketMovement = 9900; // Slippage: 1%
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            
            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const balUSDCInitial = await usdc.balanceOf(owner.address);

            // Get wallet
            const signerProvider = owner.provider!;
            const wallet0PK = ethers.Wallet.createRandom().privateKey;
            const wallet0 = new ethers.Wallet(wallet0PK, signerProvider);

            // Make deposit
            const data = getVaultData();
            await owner.sendTransaction({to: wallet0.address, value: ethers.utils.parseEther('1')});
            await usdc.transfer(wallet0.address, balUSDCInitial);
            await usdc.connect(wallet0).approve(vault.address, balUSDCInitial);
            await vault.depositUSD(balUSDCInitial, 9900, wallet0.address, wallet0.address, data);
            const balLPShares = await pair.balanceOf(wallet0.address);

            // Run

            // Permit share transfer (gasless)
            const { sig, deadline } = await getPermitSignature(
                wallet0,
                vault.address,
                pair,
                balLPShares,
                '1'
            );
            // Get permit for allowance
            await pair.permit(
                wallet0.address,
                vault.address,
                balLPShares,
                deadline,
                sig.v,
                sig.r,
                sig.s,
            );

            // Permit withdrawal transaction (gasless)
            // Get signature for deposit
            const metaTxRes = await getTransactPermitSignature(
                wallet0,
                vault,
                'ZVault UniswapV2',
                balLPShares,
                maxMarketMovement,
                'withdraw',
                data
            );
            // Make withdrawal meta transaction
            const tx = await vault.transactUSDWithPermit(
                wallet0.address,
                balLPShares,
                maxMarketMovement,
                1, // Withdrawal
                metaTxRes.deadline,
                data,
                {
                    v: metaTxRes.sig.v,
                    r: metaTxRes.sig.r,
                    s: metaTxRes.sig.s,
                }
            );

            // Test

            // Assert that earnings ocurred on the second withdrawal
            await expect(tx).to.emit(vault, 'WithdrawUSD');
        });
    });
});