import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";

describe('ControllerXChain', () => {
    async function deployControllerXChainFixture() {
        
    }

    describe('Depoloyment', () => {
        xit('Should set the right initial values and owner', async () => {
            // TODO
        });
    });

    describe('Setters', () => {
        xit('Should set key cross chain parameters', async () => {
            // TODO
        });

        xit('Should set swap parameters', async () => {
            // TODO
        });
    });

    describe('Deposits', () => {
        xit('Should ENCODE a cross chain deposit request', async () => {

        });

        xit('Should get a QUOTE for a cross chain deposit', async () => {

        });

        xit('Should SEND a cross chain deposit request', async () => {

        });

        xit('Should RECEIVE a cross chain deposit request', async () => {

        });
    });

    describe('Withdrawals', () => {
        xit('Should ENCODE a cross chain withdrawal request', async () => {

        });

        xit('Should get a QUOTE for a cross chain withdrawal', async () => {

        });

        xit('Should SEND a cross chain withdrawal request', async () => {

        });

        xit('Should RECEIVE a cross chain withdrawal request', async () => {

        });
    });
});