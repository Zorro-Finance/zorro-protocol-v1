import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs } from '../../helpers/deployments/vaults/VaultUniswapV2/deployment';
import { zeroAddress, chains, vaultFees } from "../../helpers/constants";

describe('VaultBase', () => {
    async function deployVaultBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs('avalanche', 'TJ_AVAX_USDC', owner.address, owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const beacon = await upgrades.deployBeacon(Vault);
        await beacon.deployed();

        const vault = await upgrades.deployBeaconProxy(beacon, Vault, initArgs, {
            kind: 'beacon',
        });
        await vault.deployed();

        return { vault, owner, otherAccount };
    }

    describe('Depoloyment', () => {
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
            const name = await vault.name();
            const symbol = await vault.symbol();
            const decimals = await vault.decimals();

            // Test
            expect(treasury).to.equal(chains.avalanche!.admin.multiSigOwner);
            expect(router).to.equal(chains.avalanche!.infra.uniRouterAddress);
            expect(stablecoin).to.equal(chains.avalanche!.tokens.usdc);
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

        it('Should set swap paths', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const newSwapPath = [];
            for (let i = 0; i < 2; i++) {
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

    describe('Gasless', () => {
        it('should permit gasless approval', async () => {
            // Prep
            // Get vault
            const { vault, owner } = await loadFixture(deployVaultBaseFixture);
            const vaultName = await vault.name();

            // Get wallet
            const provider = ethers.getDefaultProvider();
            const signerProvider = owner.provider!;
            const wallet0PK = ethers.Wallet.createRandom().privateKey;
            const wallet0 = new ethers.Wallet(wallet0PK, signerProvider);
            const wallet1PK = ethers.Wallet.createRandom().privateKey;
            const wallet1 = new ethers.Wallet(wallet1PK, signerProvider);

            // Get chain
            const { chainId } = await signerProvider.getNetwork();

            // Sign a permit transaction
            const domain = {
                name: vaultName,
                version: '1',
                chainId, // 0xA86A,
                verifyingContract: vault.address,
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
            const nonce = await vault.nonces(wallet0.address);
            const now = await time.latest();
            const deadline = now + 600;
            const amount = ethers.utils.parseEther('1');
            const value = {
                owner: wallet0.address,
                spender: wallet1.address,
                value: amount,
                nonce,
                deadline,
            };

            const signature = await wallet0._signTypedData(domain, types, value);
            const sig = ethers.utils.splitSignature(signature);

            // Run
            // Send permit request
            const gasPrice = await provider.getGasPrice();
            const data = vault.interface.encodeFunctionData('permit', [
                wallet0.address,
                wallet1.address,
                amount,
                deadline,
                sig.v,
                sig.r,
                sig.s,
            ]);
            const tx = await owner.sendTransaction({
                to: vault.address,
                data,
                gasPrice,
                gasLimit: 100000 //hardcoded gas limit; change if needed   
            });
            await tx.wait();

            // Test
            // Verify that signature was calculated correctly and signed by signer
            const recovered = ethers.utils.verifyTypedData(
                domain,
                types,
                value,
                sig
            );
            expect(recovered).to.equal(wallet0.address);

            // Verify approval
            expect(await vault.allowance(wallet0.address, wallet1.address)).to.equal(amount);
        });
    });
});