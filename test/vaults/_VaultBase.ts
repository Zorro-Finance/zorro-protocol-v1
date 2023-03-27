import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe('VaultBase', () => {
    async function deployVaultBaseFixture() {
        // TODO
    }

    describe('Depoloyment', () => {
        xit('Should set the right initial values and owner', async () => {
            // TODO

            // TODO: Including ERC20 token params
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