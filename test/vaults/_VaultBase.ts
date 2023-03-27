import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments';
import { zeroAddress } from "../../helpers/constants";

describe('VaultBase', () => {
    async function deployVaultBaseFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        // Get init arguments for contract deployment
        const initArgs: any[] = deploymentArgs(owner.address).avax.VaultAMM.TJ_AVAX_USDC;

        // Get contract factory
        const Vault = await ethers.getContractFactory('TJ_AVAX_USDC');
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
            // TODO: Change these to actual values (not zero)
            expect(treasury).to.equal(zeroAddress);
            expect(router).to.equal(zeroAddress);
            expect(stablecoin).to.equal(zeroAddress);
            expect(entranceFeeFactor).to.equal(0);
            expect(withdrawFeeFactor).to.equal(0);
            expect(defaultSlippageFactor).to.equal(9900);
            expect(name).to.equal('ZOR LP Vault');
            expect(symbol).to.equal('ZLPV');
            expect(decimals).to.equal(18);
        });
    });

    describe('Setters', () => {
        xit('Should set the treasury', async () => {
            // TODO
        });

        xit('Should set fee parameters', async () => {
            // TODO
        });

        xit('Should set the default slippage factor', async () => {
            // TODO
        });

        xit('Should set swap paths', async () => {
            // TODO
        });

        xit('Should set a price feed for a token', async () => {
            // TODO
        });
    });
});