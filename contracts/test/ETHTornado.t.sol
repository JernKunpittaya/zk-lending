// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console.sol";
// import {Groth16Verifier} from "src/Verifier.sol";
import {ETHTornado, IVerifier, IHasher} from "src/ETHTornado.sol";

contract ETHTornadoTest is Test {
    uint256 public constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    IVerifier public verifier;
    ETHTornado public mixer;

    // Test vars
    address public recipient = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public relayer = address(0);
    uint256 public fee = 0;
    uint256 public refund = 0;

    function deployPoseidon(bytes memory bytecode) public returns (address) {
        address deployedAddress;
        assembly {
            deployedAddress := create(0, add(bytecode, 0x20), mload(bytecode))
            if iszero(deployedAddress) { revert(0, 0) }
        }
        return deployedAddress;
    }

    function setUp() public {
        // Deploy Poseidon hasher contract.
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/deployPoseidon.js";

        bytes memory poseidonBytecode = vm.ffi(inputs);

        address poseidonHasher;
        assembly {
            poseidonHasher := create(0, add(poseidonBytecode, 0x20), mload(poseidonBytecode))
            if iszero(poseidonHasher) { revert(0, 0) }
        }

        // Deploy Groth16 verifier contract.
        // verifier = IVerifier(address(new Groth16Verifier()));

        /**
         * Deploy mixer as zk-lending when they only lend
         *
         * - verifier: Groth16 verifierwghat
         * - hasher: Poseidon hasher
         * - denomination: 1 ETH
         * - merkleTreeHeight: 20
         */
        mixer = new ETHTornado(verifier, IHasher(poseidonHasher), 1 ether, 20);
    }

    function _getWitnessAndProof(
        bytes32 _nullifier,
        bytes32 _secret,
        address _recipient,
        address _relayer,
        bytes32[] memory leaves
    ) internal returns (uint256[2] memory, uint256[2][2] memory, uint256[2] memory, bytes32, bytes32) {
        string[] memory inputs = new string[](8 + leaves.length);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/generateWitness.js";
        inputs[2] = vm.toString(_nullifier);
        inputs[3] = vm.toString(_secret);
        inputs[4] = vm.toString(_recipient);
        inputs[5] = vm.toString(_relayer);
        inputs[6] = "0";
        inputs[7] = "0";

        for (uint256 i = 0; i < leaves.length; i++) {
            inputs[8 + i] = vm.toString(leaves[i]);
        }

        bytes memory result = vm.ffi(inputs);
        (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, bytes32 root, bytes32 nullifierHash) =
            abi.decode(result, (uint256[2], uint256[2][2], uint256[2], bytes32, bytes32));

        return (pA, pB, pC, root, nullifierHash);
    }

    function _getCommitment(uint256 lend_amt, uint256 borrow_amt, uint256 will_liq_price, uint256 timestamp) internal returns (bytes32 commitment, bytes32 nullifier, bytes32 secret) {
        string[] memory inputs = new string[](6);
        inputs[0] = "node";
        inputs[1] = "forge-ffi-scripts/generateCommitment.js";
        inputs[2] = vm.toString(lend_amt);
        inputs[3] = vm.toString(borrow_amt);
        inputs[4] = vm.toString(will_liq_price);
        inputs[5] = vm.toString(timestamp);


        bytes memory result = vm.ffi(inputs);
        (commitment, nullifier, secret) = abi.decode(result, (bytes32, bytes32, bytes32));

        return (commitment, nullifier, secret);
    }

    function test_mixer_single_deposit() public {
        // 1. Generate commitment and deposit
        (bytes32 commitment, bytes32 nullifier, bytes32 secret) = _getCommitment(1000, 0, 0, block.timestamp);
        mixer.deposit{value: 1 ether}(commitment);

        // 2. Generate witness and proof.
        // bytes32[] memory leaves = new bytes32[](1);
        // leaves[0] = commitment;
        // (uint256[2] memory pA, uint256[2][2] memory pB, uint256[2] memory pC, bytes32 root, bytes32 nullifierHash) =
        //     _getWitnessAndProof(nullifier, secret, recipient, relayer, leaves);

        // // 3. Verify proof against the verifier contract.
        // assertTrue(
        //     verifier.verifyProof(
        //         pA,
        //         pB,
        //         pC,
        //         [
        //             uint256(root),
        //             uint256(nullifierHash),
        //             uint256(uint160(recipient)),
        //             uint256(uint160(relayer)),
        //             fee,
        //             refund
        //         ]
        //     )
        // );

        // 4. Withdraw funds from the contract.
        // assertEq(recipient.balance, 0);
        // assertEq(address(mixer).balance, 1 ether);
        // mixer.withdraw(pA, pB, pC, root, nullifierHash, recipient, relayer, fee, refund);
        // assertEq(recipient.balance, 1 ether);
        // assertEq(address(mixer).balance, 0);
    }

}
