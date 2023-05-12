import { time, loadFixture, mine } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from '../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment';
import { chains } from "../../helpers/constants";
import { BigNumber, BigNumberish, Contract, ContractFactory, Signer, Wallet } from "ethers";
import { Provider } from "@ethersproject/providers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Interface } from "@ethersproject/abi";

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avalanche', 'TJ_AVAX_USDC', owner.address, owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const vault = await upgrades.deployProxy(Vault, initArgs);
        await vault.deployed();

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

    async function getPermitSignature(
        owner: SignerWithAddress | Wallet,
        spender: string,
        token: Contract,
        amount: BigNumber
    ) {
        // Get chain
        const { chainId } = await owner.provider!.getNetwork();
        console.log('chainId from owner provider: ', chainId);

        // Sign a permit transaction
        const domain = {
            name: await token.name(),
            version: '2',
            chainId, // 0xA86A,
            verifyingContract: token.address,
        };
        const types = {
            Permit: [
                { name: 'owner', type: 'address' },
                { name: 'spender', type: 'address' },
                { name: 'value', type: 'uint256' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
            ],
        };
        const nonce = await token.nonces(owner.address);
        const now = await time.latest();
        const deadline = now + 600;
        const value = {
            owner: owner.address,
            spender,
            value: amount,
            nonce,
            deadline,
        };

        // Calculate and return serialized and split sigs
        const signature = await owner._signTypedData(domain, types, value);
        const sig = ethers.utils.splitSignature(signature);

        return { signature, sig, deadline }
    }

    async function getTransactPermitSignature(
        signer: SignerWithAddress | Wallet,
        vault: Contract,
        amount: BigNumber,
        maxSlippageFactor: BigNumberish,
        direction: 'deposit' | 'withdraw'
    ) {
        // Get chain
        const { chainId } = await signer.provider!.getNetwork();

        // Sign a permit transaction
        const domain = {
            name: await vault.name(),
            version: '1',
            chainId, // 0xA86A,
            verifyingContract: vault.address,
        };
        const types = {
            TransactUSDPermit: [
                { name: 'account', type: 'address' },
                { name: 'amount', type: 'uint256' },
                { name: 'maxMarketMovement', type: 'uint256' },
                { name: 'direction', type: 'uint8' },
                { name: 'nonce', type: 'uint256' },
                { name: 'deadline', type: 'uint256' },
            ],
        };
        const nonce = await vault.nonces(signer.address);
        const now = await time.latest();
        const deadline = now + 600;
        const value = {
            account: signer.address,
            amount,
            maxMarketMovement: maxSlippageFactor,
            direction: direction === 'deposit' ? 0 : 1,
            nonce,
            deadline,
        };

        // Calculate and return serialized and split sigs
        const signature = await signer._signTypedData(domain, types, value);
        const sig = ethers.utils.splitSignature(signature);

        return { signature, sig, deadline }
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
            expect(await vault.swapPathLength(chains.avalanche!.tokens.wavax, chains.avalanche!.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avalanche!.tokens.usdc, chains.avalanche!.tokens.usdc)).to.equal(0);
            expect(await vault.swapPathLength(chains.avalanche!.tokens.wavax, chains.avalanche!.tokens.usdc)).to.equal(2);
            expect(await vault.swapPathLength(chains.avalanche!.tokens.joe, chains.avalanche!.tokens.wavax)).to.equal(2);
            expect(await vault.swapPathLength(chains.avalanche!.tokens.joe, chains.avalanche!.tokens.usdc)).to.equal(2);

            // Check price feeds
            expect(await vault.priceFeeds(chains.avalanche!.tokens.wavax)).to.equal(chains.avalanche!.priceFeeds.avax);
            expect(await vault.priceFeeds(chains.avalanche!.tokens.usdc)).to.equal(chains.avalanche!.priceFeeds.usdc);
            expect(await vault.priceFeeds(chains.avalanche!.tokens.joe)).to.equal(chains.avalanche!.priceFeeds.joe);

            // Test
            expect(asset).to.equal(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            expect(token0).to.equal(chains.avalanche!.tokens.wavax);
            expect(token1).to.equal(chains.avalanche!.tokens.usdc);
            expect(farmContract).to.equal(chains.avalanche!.protocols.traderjoe.masterChef);
            expect(rewardsToken).to.equal(chains.avalanche!.tokens.joe);
            expect(isFarmable).to.equal(true);
            expect(pid).to.equal(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pid);
            expect(pool).to.equal(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
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
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Test

            // Shares are added, proportional to the new size of the vault
            expect(await vault.balanceOf(owner.address)).to.equal(amountLP);

            // Total supply reflects the amount of asset token added
            expect(await vault.totalSupply()).to.equal(amountLP);

            // Amount of tokens locked should equal the quantity of asset token added
            expect(await vault.assetLockedTotal()).to.equal(amountLP);

            // Asset token deposited gets farmed
            expect(await vault.amountFarmed()).to.equal(amountLP);
        });

        it('Deposits asset token twice', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP.mul(2));
            // Deposit once
            await vault.deposit(amountLP);
            // Deposit twice
            await vault.deposit(amountLP);

            // Test

            // Total shares/supply should be the amount deposited
            const depositFee = 9900;
            expect(await vault.totalSupply()).to.equal(amountLP.add(amountLP.mul(depositFee).div(10000)));
            expect(await vault.assetLockedTotal()).to.equal(amountLP.mul(2).sub(amountLP.div(100)));
            expect(await vault.amountFarmed()).to.be.closeTo(amountLP.add(amountLP.mul(depositFee).div(10000)), 10);
        });

        it('Deposits USD', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const balUSDC = await usdc.balanceOf(owner.address);
            const amountUSDC = balUSDC.div(10);

            // Run
            await usdc.approve(vault.address, amountUSDC);
            await vault.depositUSD(amountUSDC, 9900);

            // Test

            expect(await vault.totalSupply()).to.be.greaterThan(0);
            expect(await vault.assetLockedTotal()).to.be.greaterThan(0);
        });
    });

    describe('Withdrawals', () => {
        xit('Withdraws main asset token (full withdrawal)', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Make deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Run

            // Make withdrawal
            const shares = await vault.totalSupply();
            await vault.approve(vault.address, shares);
            await vault.withdraw(shares, 9900);

            // Test

            // Withdraws all shares
            expect(await vault.totalSupply()).to.equal(0);

            // Sets total asset locked back to zero
            expect(await vault.assetLockedTotal()).to.equal(0);

            // Asset token unfarmed
            expect(await vault.amountFarmed()).to.equal(0);
        });

        it('Withdraws main asset token twice (partial withdrawals)', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const amountLP = await pair.balanceOf(owner.address);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avalanche!.protocols.traderjoe.masterChef!);

            // Make deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Run

            // Make withdrawal 1
            const shares = await vault.totalSupply();
            await vault.approve(vault.address, shares.div(2));
            await vault.withdraw(shares.div(2), 9900);

            // Expect roughly the amount returned to equal the amount deposited minus fees
            expect(await pair.balanceOf(owner.address)).to.be.closeTo((amountLP.div(2)).mul(99).div(100), 10);

            // Expect the shares to be decremented by the amount deposited
            expect(await vault.totalSupply()).to.be.closeTo(amountLP.div(2), 10);

            // Expect the amount still farmed to be equal to the amount depoisted
            expect(await vault.amountFarmed()).to.be.closeTo(amountLP.div(2), 10);

            // Advance a few blocks and update masterchef pool rewards
            for (let i = 0; i < 100; i++) {
                await masterChef.updatePool(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pid!);
            }

            // Make withdrawal 2
            const sharesRemaining = await vault.totalSupply();
            await vault.approve(vault.address, sharesRemaining);
            const tx = await vault.withdraw(sharesRemaining, 9000);
            const receipt = await tx.wait();

            // Test

            // Withdraws all shares
            expect(await vault.totalSupply()).to.equal(0);

            // Sets total asset locked back to zero
            expect(await vault.assetLockedTotal()).to.equal(0);

            // Asset token unfarmed
            expect(await vault.amountFarmed()).to.equal(0);

            // Encode event logs
            const reinvestSig = ethers.utils.id('ReinvestEarnings(uint256,address)');

            // Find matching log
            let matchingLog: any | undefined = undefined;
            for (let log of receipt.logs) {
                if (log.topics[0] === reinvestSig) {
                    matchingLog = log;
                    break;
                }
            }

            // Assert that earnings ocurred on the second withdrawal
            expect(matchingLog).to.not.be.undefined;
        });

        xit('Withdraws to USD', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Make deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Run

            // Make withdrawal via USD
            const shares = await vault.totalSupply();
            await vault.approve(vault.address, shares);
            await vault.withdrawUSD(shares, 9900);

            // Test

            expect(await vault.totalSupply()).to.equal(0);
            expect(await vault.assetLockedTotal()).to.equal(0);
        });
    });

    describe('Gasless', () => {
        it('Deposits USD as a meta transaction', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('ERC20PermitUpgradeable', chains.avalanche!.tokens.usdc);
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
                amountUSDC
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

            console.log('usdbal: ', await usdc.allowance(wallet0.address, vault.address));
            console.log('amountusdc for tx: ', amountUSDC);
            // Get signature for deposit
            const metaTxRes = await getTransactPermitSignature(
                wallet0,
                vault,
                amountUSDC,
                maxMarketMovement,
                'deposit'
            );
            // Make deposit meta transaction
            await vault.transactUSDWithPermit(
                wallet0.address,
                amountUSDC,
                maxMarketMovement,
                0, // Deposit
                metaTxRes.deadline,
                metaTxRes.sig.v,
                metaTxRes.sig.r,
                metaTxRes.sig.s,
            );

            // Test
            // TODO
        });

        it('Withdraws shares to USD as a meta transaction', async () => {

        });
    });

    describe('Earnings', () => {
        it('Compounds (reinvests) farm rewards', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avalanche!.protocols.traderjoe.masterChef!);

            // Run

            // Deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Advance blocks (need many to produce enough rewards)
            mine(1000);

            // Earn
            const tx = await vault.earn(9000, false); // 10% slippage. WARNING: Because of low rewards after time elapsed in test, test could fail if slippage set incorrectly

            const receipt = await tx.wait();

            // Test

            // Expect asset token balance to have grown as a result of compounding
            expect(await vault.amountFarmed()).to.be.greaterThan(amountLP);

            // Expect last earnings block to have been updated
            expect(await vault.lastEarn()).to.equal(await ethers.provider.getBlockNumber());

            // Expect log to be emitted

            // Encode event logs
            const reinvestSig = ethers.utils.id('ReinvestEarnings(uint256,address)');

            // Find matching log
            let matchingLog: any | undefined = undefined;
            for (let log of receipt.logs) {
                if (log.topics[0] === reinvestSig) {
                    matchingLog = log;
                    break;
                }
            }
            expect(matchingLog).to.not.be.undefined;
        });
    });

    describe('Utilities', () => {
        it('Should calculuate amount farmed', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avalanche!.protocols.traderjoe.masterChef!);

            // Run

            // Deposit
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);

            // Advance a few blocks and update masterchef pool rewards
            for (let i = 0; i < 5; i++) {
                await masterChef.updatePool(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pid!);
            }

            // Test
            expect(await vault.amountFarmed()).to.equal(amountLP);
        });

        it('Should calculuate pending rewards farmed', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);

            // Get farm contract
            const masterChef = await ethers.getContractAt('IBoostedMasterChefJoe', chains.avalanche!.protocols.traderjoe.masterChef!);

            // Get LP Token
            await getAssets(ethers.utils.parseEther('10'));
            const pair = await ethers.getContractAt('IUniswapV2Pair', chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pool);
            const balLP = await pair.balanceOf(owner.address);
            const amountLP = balLP.div(10);

            // Run
            await pair.approve(vault.address, amountLP);
            await vault.deposit(amountLP);
            // Advance a few blocks and update masterchef pool rewards
            for (let i = 0; i < 5; i++) {
                await masterChef.updatePool(chains.avalanche!.protocols.traderjoe.pools.AVAX_USDC.pid!);
            }

            // Test
            expect(await vault.pendingRewards()).to.be.greaterThan(0);
        });
    });
});