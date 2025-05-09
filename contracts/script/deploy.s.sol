// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {zkLend, IHasher} from "src/zkLend.sol";
import {MockToken} from "src/MockToken.sol";
import {HonkVerifier} from "src/Verifier.sol";

contract zkLendTest is Script {
    HonkVerifier public verifier;
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    zkLend public zk_lend_mixer;
    MockToken public mUSDC;
    MockToken public mETH;
    IHasher public hasher;

    function deployPoseidon(bytes memory bytecode) public returns (address) {
        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(deployedAddress) {
                revert(0, 0)
            }
        }
        return deployedAddress;
    }

    function run() public {
        // Deploy Poseidon hasher contract.
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/deployPoseidon.js";

        bytes memory poseidonBytecode = vm.ffi(inputs);

        address poseidonHasher;
        assembly {
            poseidonHasher := create(
                0,
                add(poseidonBytecode, 0x20),
                mload(poseidonBytecode)
            )
            if iszero(poseidonHasher) {
                revert(0, 0)
            }
        }
        mUSDC = new MockToken("USDC", "USDC", 6, 1_000_000 * 1e6);
        mETH = new MockToken("wETH", "wETH", 6, 1_000_000 * 1e6);
        verifier = new HonkVerifier();
        hasher = IHasher(poseidonHasher);

        zk_lend_mixer = new zkLend(verifier, hasher, 12, mETH, mUSDC);
        // mUSDC.mint(address(zk_lend_mixer), 1_000_000 * 1e6);
        // mETH.mint(address(zk_lend_mixer), 100_000 * 1e18);
    }
}
