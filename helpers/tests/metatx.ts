import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish, Contract, ContractFactory, Signer, Wallet } from "ethers";

export async function getPermitSignature(
    owner: SignerWithAddress | Wallet,
    spender: string,
    token: Contract,
    amount: BigNumber,
    version: string,
) {
    // Get chain
    const { chainId } = await owner.provider!.getNetwork();

    // Sign a permit transaction
    const domain = {
        name: await token.name(),
        version,
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

export async function getTransactPermitSignature(
    signer: SignerWithAddress | Wallet,
    vault: Contract,
    vaultName: string,
    amount: BigNumber,
    maxSlippageFactor: BigNumberish,
    direction: 'deposit' | 'withdraw',
    data: string
) {
    // Get chain
    const { chainId } = await signer.provider!.getNetwork();

    // Sign a permit transaction
    const domain = {
        name: vaultName,
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
            { name: 'data', type: 'bytes' },
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
        data,
    };

    // Calculate and return serialized and split sigs
    const signature = await signer._signTypedData(domain, types, value);
    const sig = ethers.utils.splitSignature(signature);

    return { signature, sig, deadline }
}

export async function getXCRequestPermitSignature(
    signer: SignerWithAddress | Wallet,
    controller: Contract,
    request: XCPermitRequest,
    xcfee: BigNumber,
    direction: 'deposit' | 'withdraw'
) {
    // Get chain
    const { chainId } = await signer.provider!.getNetwork();

    // Sign a permit transaction
    const domain = {
        name: 'ZXC Controller',
        version: '1',
        chainId, // 0xA86A,
        verifyingContract: controller.address,
    };
    const types = {
        SendRequestPermit: [
            { name: 'request', type: 'XCPermitRequest' },
            { name: 'direction', type: 'uint8' },
            { name: 'xcfee', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
        ],
        XCPermitRequest: [
            { name: 'dstChain', type: 'uint16' },
            { name: 'dstPoolId', type: 'uint256' },
            { name: 'remoteControllerXChain', type: 'address' },
            { name: 'vault', type: 'address' },
            { name: 'originWallet', type: 'address' },
            { name: 'dstWallet', type: 'address' },
            { name: 'amount', type: 'uint256' },
            { name: 'slippageFactor', type: 'uint256' },
            { name: 'dstGasForCall', type: 'uint256' },
            { name: 'data', type: 'bytes' },
        ],
    };
    const nonce = await controller.nonces(signer.address);
    const now = await time.latest();
    const deadline = now + 600;
    const value = {
        request,
        direction: direction === 'deposit' ? 0 : 1,
        xcfee,
        nonce,
        deadline,
    };

    // Calculate and return serialized and split sigs
    const signature = await signer._signTypedData(domain, types, value);
    const sig = ethers.utils.splitSignature(signature);

    return { signature, sig, deadline }
}

export interface XCPermitRequest {
    dstChain: number;
    dstPoolId: number;
    remoteControllerXChain: string;
    vault: string;
    originWallet: string;
    dstWallet: string;
    amount: BigNumber;
    slippageFactor: number;
    dstGasForCall: BigNumber;
    data: string;
}