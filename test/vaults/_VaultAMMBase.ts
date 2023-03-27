import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe('VaultAMMBase', () => {
    async function deployVaultAMMBaseFixture() {
        // TODO
    }

    describe('Depoloyment', () => {
        xit('Should set the right initial values and owner', async () => {
            // TODO
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