import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { deploymentArgs as deploymentArgsController } from "../../helpers/deployments/controllers/ControllerXChain/deployment";
import { deploymentArgs as deploymentArgsVault } from "../../helpers/deployments/vaults/VaultAMM/TraderJoe/deployment";
import { chains } from "../../helpers/constants";
import { BigNumber } from "ethers";
import { 
    getPermitSignature,
    getXCRequestPermitSignature,
} from "../../helpers/tests/metatx";
import { eventDidEmit } from "../../helpers/deployments/utilities";

describe('ControllerXChain', () => {
    async function deployControllerXChainFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgsController('avalanche', owner.address);

        // Get contract factory
        const Controller = await ethers.getContractFactory('ControllerXChain');
        const controller = await upgrades.deployProxy(Controller, initArgs);
        await controller.deployed();

        return { controller, owner, otherAccount };
    }

    async function deployVaultAMMBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgsVault('avalanche', 'TJ_AVAX_USDC', owner.address, owner.address);

        // Get contract factory
        const Vault = await ethers.getContractFactory('TraderJoeAMMV1');
        const beacon = await upgrades.deployBeacon(Vault);
        await beacon.deployed();

        const vault = await upgrades.deployBeaconProxy(beacon.address, Vault, initArgs, {
            kind: 'beacon',
        });
        await vault.deployed();

        return { vault, owner, otherAccount };
    }

    async function getAssets(amountETH: BigNumber) {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get router
        const router = await ethers.getContractAt('IJoeRouter02', chains.avalanche!.infra.uniRouterAddress);

        // Get min USDC out and account for some slippage 
        const path = [chains.avalanche!.tokens.wavax, chains.avalanche!.tokens.usdc];
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
    }

    describe('Depoloyment', () => {
        it('Should set the right initial values and owner', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);

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
            expect(layerZeroEndpoint).to.equal(chains.avalanche!.infra.layerZeroEndpoint);
            expect(stargateRouter).to.equal(chains.avalanche!.infra.stargateRouter);
            expect(currentChain).to.equal(chains.avalanche!.xChain.lzChainId);
            expect(sgPoolId).to.equal(chains.avalanche!.xChain.sgPoolId);

            expect(router).to.equal(chains.avalanche!.infra.uniRouterAddress);
            expect(stablecoin).to.equal(chains.avalanche!.tokens.usdc);
            expect(stablecoinPriceFeed).to.equal(chains.avalanche!.priceFeeds.usdc);
            expect(_owner).to.equal(owner.address);
        });
    });

    describe('Setters', () => {
        it('Should set key cross chain parameters', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
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
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const newRouter = ethers.Wallet.createRandom().address;
            const newStablecoin = ethers.Wallet.createRandom().address;
            const newWETH = ethers.Wallet.createRandom().address;
            const newStablecoinPriceFeed = ethers.Wallet.createRandom().address;
            const newETHPriceFeed = ethers.Wallet.createRandom().address;
            const newSlippageFactor = 7000;

            // Run
            await controller.setSwapParams(
                newRouter,
                newStablecoin,
                newWETH,
                newStablecoinPriceFeed,
                newETHPriceFeed,
                newSlippageFactor
            );

            // Test
            expect(await controller.router()).to.equal(newRouter);
            expect(await controller.stablecoin()).to.equal(newStablecoin);
            expect(await controller.WETH()).to.equal(newWETH);
            expect(await controller.stablecoinPriceFeed()).to.equal(newStablecoinPriceFeed);
            expect(await controller.ethPriceFeed()).to.equal(newETHPriceFeed);
            expect(await controller.defaultSlippageFactor()).to.equal(newSlippageFactor);
        });
    });

    describe('Deposits', () => {
        it('Should ENCODE a cross chain deposit request', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const vault = ethers.Wallet.createRandom().address;
            const valueUSD = ethers.utils.parseUnits('1', 'mwei');
            const wallet = ethers.Wallet.createRandom().address;
            const slippageFactor = 9900;
            const encoded = controller.interface.encodeFunctionData(
                'receiveDepositRequest',
                [vault, valueUSD, slippageFactor, wallet]
            );

            // Run
            const encodedRes = await controller.encodeDepositRequest(
                vault,
                valueUSD,
                slippageFactor,
                wallet
            );

            // Test
            expect(encodedRes).to.equal(encoded);
        });

        it('Should get a QUOTE for a cross chain deposit', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const dstChain = 102; // BNB
            const dstContract = ethers.Wallet.createRandom().address;
            const vault = ethers.Wallet.createRandom().address;
            const valueUSD = ethers.utils.parseUnits('1', 'mwei');
            const wallet = ethers.Wallet.createRandom().address;
            const slippageFactor = 9900;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');
            const payload = controller.interface.encodeFunctionData(
                'receiveDepositRequest',
                [vault, valueUSD, slippageFactor, wallet]
            );

            // Run
            const nativeFee = await controller.getDepositQuote(
                dstChain,
                dstContract,
                payload,
                dstGasForCall
            );

            // Test
            expect(nativeFee).to.be.greaterThan(0);
        });

        it('Should SEND a cross chain deposit request', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const dstChain = 102; // BNB
            const dstPoolId = 5; // BUSD
            const remoteControllerXChainAddr = ethers.Wallet.createRandom().address;
            const abiEncoder = ethers.utils.defaultAbiCoder;
            const remoteControllerXChain = abiEncoder.encode(['address'], [remoteControllerXChainAddr]);
            const vault = ethers.Wallet.createRandom().address;
            const dstWallet = ethers.Wallet.createRandom().address;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');

            // USD prep
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const amountUSD = (await usdc.balanceOf(owner.address)).div(10);
            const slippageFactor = 9900;

            // Deposit quote
            const payload = controller.interface.encodeFunctionData(
                'receiveDepositRequest',
                [vault, amountUSD, slippageFactor, dstWallet]
            );
            const nativeFee = await controller.getDepositQuote(
                dstChain,
                remoteControllerXChain,
                payload,
                dstGasForCall
            );

            // Run
            await usdc.approve(controller.address, amountUSD);
            const tx = await controller.sendDepositRequest(
                dstChain,
                dstPoolId,
                remoteControllerXChain,
                vault,
                dstWallet,
                amountUSD,
                slippageFactor,
                dstGasForCall,
                {value: nativeFee}
            );
            const receipt = await tx.wait();

            // Test
            expect(eventDidEmit('SendMsg(uint8,uint64)', receipt)).to.be.true;
        });

        it('Should RECEIVE a cross chain deposit request', async () => {
            // Prep

            // Get contracts
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const { vault } = await loadFixture(deployVaultAMMBaseFixture);

            // Get assets
            await getAssets(ethers.utils.parseEther('10'));

            // Args for receiver
            const chainId = 102; // BNB source chain
            const srcAddress = ethers.Wallet.createRandom().address;
            const nonce = 4096;

            // Payload for receiving deposit
            const slippageFactor = 9900;
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const valueUSD = (await usdc.balanceOf(owner.address)).div(10);
            const payload = controller.interface.encodeFunctionData(
                'receiveDepositRequest',
                [vault.address, valueUSD, slippageFactor, owner.address]
            );

            // Simulate sending USDC to controller
            await usdc.transfer(controller.address, valueUSD);

            // Allow bypassing onlyRegEndpoint modifier
            const layerZeroEndpoint = await controller.layerZeroEndpoint();
            const currentChain = await controller.currentChain();
            const sgPoolId = await controller.sgPoolId();
            await controller.setKeyXChainParams(
                layerZeroEndpoint,
                owner.address,
                currentChain,
                sgPoolId
            );

            // Run

            // Simulate receiving message from Stargate router
            await controller.sgReceive(
                chainId, 
                srcAddress,
                nonce,
                usdc.address,
                valueUSD,
                payload
            );


            // Test

            expect(await vault.balanceOf(owner.address)).to.be.greaterThan(0);
        });
    });

    describe('Withdrawals', () => {
        it('Should ENCODE a cross chain withdrawal request', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const wallet = ethers.Wallet.createRandom().address;
            const encoded = controller.interface.encodeFunctionData(
                'receiveWithdrawalRequest',
                [wallet]
            );

            // Run
            const encodedRes = await controller.encodeWithdrawalRequest(
                wallet
            );

            // Test
            expect(encodedRes).to.equal(encoded);
        });

        it('Should get a QUOTE for a cross chain withdrawal', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const dstChain = 102; // BNB
            const dstContract = ethers.Wallet.createRandom().address;
            const wallet = ethers.Wallet.createRandom().address;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');
            const payload = controller.interface.encodeFunctionData(
                'receiveWithdrawalRequest',
                [wallet]
            );

            // Run
            const nativeFee = await controller.getDepositQuote(
                dstChain,
                dstContract,
                payload,
                dstGasForCall
            );

            // Test
            expect(nativeFee).to.be.greaterThan(0);
        });

        it('Should SEND a cross chain withdrawal request', async () => {
            // Prep

            // Contracts
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const { vault } = await loadFixture(deployVaultAMMBaseFixture);

            // Get USD
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);

            // Make deposit into vault
            const slippageFactor = 9000;
            const amountUSD = (await usdc.balanceOf(owner.address)).div(10);
            await usdc.approve(vault.address, amountUSD);
            await vault.depositUSD(amountUSD, slippageFactor);

            // Args for xchain call
            const dstChain = 102; // BNB
            const dstPoolId = 5; // BUSD
            const remoteControllerXChainAddr = ethers.Wallet.createRandom().address;
            const abiEncoder = ethers.utils.defaultAbiCoder;
            const remoteControllerXChain = abiEncoder.encode(['address'], [remoteControllerXChainAddr]);
            const shares = await vault.totalSupply();
            const dstWallet = ethers.Wallet.createRandom().address;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');

            // Run

            // Get payload
            const payload = controller.interface.encodeFunctionData(
                'receiveWithdrawalRequest',
                [dstWallet]
            );

            // Get quote
            const nativeFee = await controller.getWithdrawalQuote(
                dstChain,
                remoteControllerXChain,
                payload,
                dstGasForCall
            );

            // Approve spending of vault token
            await vault.approve(controller.address, shares);
            const tx = await controller.sendWithdrawalRequest(
                dstChain,
                dstPoolId,
                remoteControllerXChain,
                vault.address,
                shares,
                slippageFactor,
                dstWallet,
                dstGasForCall,
                {value: nativeFee}
            );
            const receipt = await tx.wait();

            // Test
            
            expect(eventDidEmit('SendMsg(uint8,uint64)', receipt)).to.be.true;
        });

        it('Should RECEIVE a cross chain withdrawal request', async () => {
            // Prep

            // Get contracts
            const { controller, owner, otherAccount } = await loadFixture(deployControllerXChainFixture);
            const { vault } = await loadFixture(deployVaultAMMBaseFixture);

            // Get assets
            await getAssets(ethers.utils.parseEther('10'));

            // Args for receiver
            const chainId = 102; // BNB source chain
            const srcAddress = ethers.Wallet.createRandom().address;
            const nonce = 4096;

            // Payload for receiving deposit
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            const valueUSD = (await usdc.balanceOf(owner.address)).div(10);
            const payload = controller.interface.encodeFunctionData(
                'receiveWithdrawalRequest',
                [otherAccount.address]
            );

            // Simulate sending USDC to controller
            await usdc.transfer(controller.address, valueUSD);

            // Allow bypassing onlyRegEndpoint modifier
            const layerZeroEndpoint = await controller.layerZeroEndpoint();
            const currentChain = await controller.currentChain();
            const sgPoolId = await controller.sgPoolId();
            await controller.setKeyXChainParams(
                layerZeroEndpoint,
                owner.address,
                currentChain,
                sgPoolId
            );

            // Run

            // Simulate receiving message from Stargate router
            await controller.sgReceive(
                chainId, 
                srcAddress,
                nonce,
                usdc.address,
                valueUSD,
                payload
            );


            // Test

            expect(await usdc.balanceOf(otherAccount.address)).to.be.greaterThan(0);
        });
    });

    describe('Gasless', () => {
        it('Deposits USD as a meta transaction, cross chain', async () => {
            // Prep
            const { vault, owner } = await loadFixture(deployVaultAMMBaseFixture);
            const { controller } = await loadFixture(deployControllerXChainFixture);
            const dstChain = 102; // BNB
            const dstPoolId = 5; // BUSD
            const remoteControllerXChainAddr = ethers.Wallet.createRandom().address;
            const dstWallet = ethers.Wallet.createRandom().address;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');

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

            // Deposit quote
            const payload = controller.interface.encodeFunctionData(
                'receiveDepositRequest',
                [vault.address, amountUSDC, maxMarketMovement, dstWallet]
            );
            const nativeFee = await controller.getDepositQuote(
                dstChain,
                remoteControllerXChainAddr,
                payload,
                dstGasForCall
            );

            // Run

            // Get permit signature from wallet
            const { sig, deadline } = await getPermitSignature(
                wallet0,
                controller.address,
                usdc,
                amountUSDC,
                '2'
            );

            // Get permit for allowance
            await usdc.permit(
                wallet0.address,
                controller.address,
                amountUSDC,
                deadline,
                sig.v,
                sig.r,
                sig.s
            );

            // Get signature for deposit
            const xcPermitRequest = {
                dstChain,
                dstPoolId,
                remoteControllerXChain: remoteControllerXChainAddr,
                vault: vault.address,
                originWallet: wallet0.address,
                dstWallet,
                amount: amountUSDC,
                slippageFactor: maxMarketMovement,
                dstGasForCall,
            };
            const metaTxRes = await getXCRequestPermitSignature(
                wallet0,
                controller,
                xcPermitRequest,
                nativeFee,
                'deposit'
            );

            // Make deposit meta transaction
            const tx = await controller.requestWithPermit(
                xcPermitRequest,
                0,
                metaTxRes.deadline,
                {
                    v: metaTxRes.sig.v,
                    r: metaTxRes.sig.r,
                    s: metaTxRes.sig.s,
                },
                {
                    value: nativeFee,
                },
            );
            const receipt = await tx.wait();

            // Test

            // Assert that cross chain message was emitted
            expect(eventDidEmit('SendMsg(uint8,uint64)', receipt)).to.be.true;
        });

        it('Withdraws shares to USD as a meta transaction, cross chain', async () => {
            // Prep
            const { controller, owner } = await loadFixture(deployControllerXChainFixture);
            const { vault } = await loadFixture(deployVaultAMMBaseFixture);
            const maxMarketMovement = 9900; // Slippage: 1%
            const dstChain = 102; // BNB
            const dstPoolId = 5; // BUSD
            const remoteControllerXChainAddr = ethers.Wallet.createRandom().address;
            const dstWallet = ethers.Wallet.createRandom().address;
            const dstGasForCall = ethers.utils.parseUnits('1', 'mwei');

            // Get USD
            await getAssets(ethers.utils.parseEther('10'));
            const usdc = await ethers.getContractAt('IERC20Upgradeable', chains.avalanche!.tokens.usdc);
            
            // Get wallet
            const signerProvider = owner.provider!;
            const wallet0PK = ethers.Wallet.createRandom().privateKey;
            const wallet0 = new ethers.Wallet(wallet0PK, signerProvider);

            // Make deposit into vault
            const slippageFactor = 9000;
            const amountUSD = (await usdc.balanceOf(owner.address)).div(10);
            await usdc.approve(vault.address, amountUSD);
            await vault.depositUSD(amountUSD, slippageFactor);

            // Transfer shars to wallet for signature
            const balShares = await vault.totalSupply();
            await vault.transfer(wallet0.address, balShares);

            // Run

            // Get quote
            const payload = controller.interface.encodeFunctionData(
                'receiveWithdrawalRequest',
                [dstWallet]
            );

            // Get quote
            const nativeFee = await controller.getWithdrawalQuote(
                dstChain,
                remoteControllerXChainAddr,
                payload,
                dstGasForCall
            );

            // Permit share transfer (gasless)
            const { sig, deadline } = await getPermitSignature(
                wallet0,
                controller.address,
                vault,
                balShares,
                '1'
            );

            // Get permit for allowance
            await vault.permit(
                wallet0.address,
                controller.address,
                balShares,
                deadline,
                sig.v,
                sig.r,
                sig.s
            );

            // Get signature for deposit
            const xcPermitRequest = {
                dstChain,
                dstPoolId,
                remoteControllerXChain: remoteControllerXChainAddr,
                vault: vault.address,
                originWallet: wallet0.address,
                dstWallet,
                amount: balShares,
                slippageFactor: maxMarketMovement,
                dstGasForCall,
            };
            const metaTxRes = await getXCRequestPermitSignature(
                wallet0,
                controller,
                xcPermitRequest,
                nativeFee,
                'withdraw'
            );

            // Make deposit meta transaction
            const tx = await controller.requestWithPermit(
                xcPermitRequest,
                1,
                metaTxRes.deadline,
                {
                    v: metaTxRes.sig.v,
                    r: metaTxRes.sig.r,
                    s: metaTxRes.sig.s,
                },
                {
                    value: nativeFee,
                },
            );
            const receipt = await tx.wait();

            // Test

            // Assert that cross chain message was emitted
            expect(eventDidEmit('SendMsg(uint8,uint64)', receipt)).to.be.true;
        });
    });
});