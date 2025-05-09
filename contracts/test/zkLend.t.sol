// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console.sol";
// import {Groth16Verifier} from "src/Verifier.sol";
import {zkLend, IHasher} from "src/zkLend.sol";
import {MockToken} from "src/MockToken.sol";
import {HonkVerifier} from "src/Verifier.sol";

contract zkLendTest is Test {
    HonkVerifier public verifier;
    uint256 public constant FIELD_SIZE =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    zkLend public zk_lend_mixer;
    MockToken public mUSDC;
    MockToken public mETH;
    IHasher public hasher;

    // Test vars
    address public recipient = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

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

    struct MyNote {
        uint256 lend_amt; // in smallest unit (scaled, e.g., x10^4)
        uint256 borrow_amt; // in smallest unit (scaled, e.g., x10^4)
        uint256 will_liq_price; // in smallest unit as integer
        uint256 timestamp;
        bytes32 nullifier;
        bytes32 secret;
    }

    function setUp() public {
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

        // Deploy Groth16 verifier contract.
        // verifier = IVerifier(address(new Groth16Verifier()));

        /**
         * Deploy mixer as zk-lending when they only lend
         *
         * - verifier: Groth16 verifierwghat
         * - hasher: Poseidon hasher
         * - merkleTreeHeight: 20
         */

        mUSDC = new MockToken("Mock USDC", "mUSDC", 6, 1_000_000 * 1e6);
        mETH = new MockToken("Mock ETH", "mETH", 6, 1_000_000 * 1e6);
        verifier = new HonkVerifier();
        hasher = IHasher(poseidonHasher);

        zk_lend_mixer = new zkLend(verifier, hasher, 12, mETH, mUSDC);
        // TODO: Shouldnt need this mint directly once we support two side market
        mUSDC.mint(address(zk_lend_mixer), 100_000 * 1e6);
        mETH.mint(address(zk_lend_mixer), 100_000 * 1e18);
    }

    // TODO: Make sure we have all required param to match BIG main circuit
    function _getWitnessAndProof(
        MyNote memory prev_note,
        MyNote memory new_note,
        uint256 _additional_borrow_amt,
        uint256[] memory liquidated_array,
        bytes32[] memory leaves
    ) internal returns (uint256, bytes32, bytes32) {
        // TODO: Make priWitness correct type & value
        string[] memory inputs = new string[](28 + leaves.length);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/generateWitness.js";
        inputs[2] = vm.toString(prev_note.lend_amt);
        inputs[3] = vm.toString(prev_note.borrow_amt);
        inputs[4] = vm.toString(prev_note.will_liq_price);
        inputs[5] = vm.toString(prev_note.timestamp);
        inputs[6] = vm.toString(prev_note.nullifier);
        inputs[7] = vm.toString(prev_note.secret);

        for (uint256 i = 0; i < liquidated_array.length; i++) {
            inputs[8 + i] = vm.toString(liquidated_array[i]);
        }

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[8 + liquidated_array.length + i] = vm.toString(leaves[i]);
        }

        bytes memory result = vm.ffi(inputs);
        (uint256 priWitness, bytes32 root, bytes32 nullifierHash) = abi.decode(
            result,
            (uint256, bytes32, bytes32)
        );

        return (priWitness, root, nullifierHash);
    }

    function _getCommitment(
        uint256 lend_amt,
        uint256 borrow_amt,
        uint256 will_liq_price,
        uint256 timestamp
    ) internal returns (bytes32 commitment, bytes32 nullifier, bytes32 secret) {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/generateCommitment.js";
        inputs[2] = vm.toString(lend_amt);
        inputs[3] = vm.toString(borrow_amt);
        inputs[4] = vm.toString(will_liq_price);
        inputs[5] = vm.toString(timestamp);

        bytes memory result = vm.ffi(inputs);
        (commitment, nullifier, secret) = abi.decode(
            result,
            (bytes32, bytes32, bytes32)
        );

        return (commitment, nullifier, secret);
    }

    function test_mixer_single_deposit() public {
        // mETH.approve(address(zk_lend_mixer), 1300000);
        // vm.warp(1746826656 + 1 minutes);
        // zk_lend_mixer.deposit(
        //     0x1296784b1c2414377826486fed0409eeee5850e3a46e73fd18ac4ce0b3d12253,
        //     0x0000000000000000000000000000000000000000000000000000000000c65d40,
        //     1746826656,
        //     0x045132221d1fa0a7f4aed8acd2cbec1e2189b7732ccb2ec272b9c60f0d5afc5b,
        //     0x0000000000000000000000000000000000000000000000000000000000000000,
        //     proof,
        //     1300000,
        //     mETH
        // );
        // // 1. Generate commitment and deposit
        // uint256 lend_amt = 10;
        // uint256 borrow_amt = 0;
        // uint256 will_liq_price = 0;
        // uint256 timestamp = block.timestamp;
        // (
        //     bytes32 commitment,
        //     bytes32 nullifier,
        //     bytes32 secret
        // ) = _getCommitment(lend_amt, borrow_amt, will_liq_price, timestamp);
        // mETH.approve(address(zk_lend_mixer), lend_amt);
        // zk_lend_mixer.deposit(commitment, lend_amt, timestamp);
        // // 2. Generate witness and proof to prove ownership of prev_note for borrow more
        // MyNote memory prev_note = MyNote({
        //     lend_amt: lend_amt,
        //     borrow_amt: borrow_amt,
        //     will_liq_price: will_liq_price,
        //     timestamp: timestamp,
        //     nullifier: nullifier,
        //     secret: secret
        // });
        // // TODO: These functions should be precomputed from frontend
        // uint256 lend_interest_update = 1;
        // uint256 additional_borrow_amt = 3;
        // uint256 new_lend_amt = prev_note.lend_amt + lend_interest_update;
        // uint256 new_borrow_amt = prev_note.borrow_amt + additional_borrow_amt;
        // // TODO: Also come from frontend
        // uint256 new_will_liq_price = 21;
        // uint256 new_timestamp = block.timestamp;
        // (
        //     bytes32 new_commitment,
        //     bytes32 new_nullifier,
        //     bytes32 new_secret
        // ) = _getCommitment(
        //         new_lend_amt,
        //         new_borrow_amt,
        //         new_will_liq_price,
        //         new_timestamp
        //     );
        // MyNote memory new_note = MyNote({
        //     lend_amt: new_lend_amt,
        //     borrow_amt: new_borrow_amt,
        //     will_liq_price: new_will_liq_price,
        //     timestamp: new_timestamp,
        //     nullifier: new_nullifier,
        //     secret: new_secret
        // });
        // bytes32[] memory leaves = new bytes32[](1);
        // leaves[0] = commitment;
        // // TODO: Fix priWitness
        // (
        //     uint256 priWitness,
        //     bytes32 root,
        //     bytes32 nullifierHash
        // ) = _getWitnessAndProof(
        //         prev_note,
        //         new_note,
        //         additional_borrow_amt,
        //         zk_lend_mixer.flatten_liquidated_array(),
        //         leaves
        //     );
        // // 3. Borrow funds from the contract. (verifying logic is in borrow function)
        // // assertEq(recipient.balance, 0);
        // // assertEq(address(mixer).balance, 1 ether);
        // zk_lend_mixer.borrow(
        //     priWitness,
        //     root,
        //     nullifierHash,
        //     new_commitment,
        //     recipient,
        //     new_will_liq_price,
        //     additional_borrow_amt
        // );
        // // assertEq(recipient.balance, 1 ether);
        // // assertEq(address(mixer).balance, 0);
    }
}
