import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import {deploymentArgs} from '../../helpers/deployments';

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
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
            // TODO fill this in! 

            const {vault, owner} = await loadFixture(deployVaultAMMBaseFixture);

        });
    });

    describe('Setters', () => {
        xit('Should set key tokens and contract addresses', async () => {
            // TODO
        });

        xit('Should set farm parameters', async () => {
            // TODO
        });
    });

    describe('Deposits', () => {
        xit('Deposits main asset token', async () => {

        });

        xit('Deposits USD', async () => {

        });
    });

    describe('Withdrawals', () => {
        xit('Withdraws main asset token', async () => {

        });

        xit('Withdraws to USD', async () => {

        });
    });

    describe('Earnings', () => {
        xit('Compounds (reinvests) farm rewards', async () => {

        });
    });
});