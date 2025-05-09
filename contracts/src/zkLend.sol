// https://tornado.cash
/*
 * d888888P                                           dP              a88888b.                   dP
 *    88                                              88             d8'   `88                   88
 *    88    .d8888b. 88d888b. 88d888b. .d8888b. .d888b88 .d8888b.    88        .d8888b. .d8888b. 88d888b.
 *    88    88'  `88 88'  `88 88'  `88 88'  `88 88'  `88 88'  `88    88        88'  `88 Y8ooooo. 88'  `88
 *    88    88.  .88 88       88    88 88.  .88 88.  .88 88.  .88 dP Y8.   .88 88.  .88       88 88    88
 *    dP    `88888P' dP       dP    dP `88888P8 `88888P8 `88888P' 88  Y88888P' `88888P8 `88888P' dP    dP
 * ooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MerkleTreeWithHistory.sol";
import "./utils/ReentrancyGuard.sol";
import {MockToken} from "./MockToken.sol";
import {IVerifier} from "./Verifier.sol";

contract zkLend is MerkleTreeWithHistory, ReentrancyGuard {
    IVerifier public immutable verifier;

    MockToken public weth;
    MockToken public usdc;

    struct Liquidated {
        uint256 liq_price;
        uint256 timestamp;
    }
    uint256 public constant LIQUIDATED_ARRAY_NUMBER = 10;
    Liquidated[] public liquidated_array =
        new Liquidated[](LIQUIDATED_ARRAY_NUMBER);

    mapping(bytes32 => bool) public nullifierHashes;
    // we store all commitments just to prevent accidental deposits with the same commitment
    mapping(bytes32 => bool) public commitments;

    event Deposit(
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Borrow(
        address to,
        bytes32 nullifierHash,
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Lend(
        bytes32 nullifierHash,
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Repay(
        bytes32 nullifierHash,
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Withdraw(
        address to,
        bytes32 nullifierHash,
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );

    // event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    // /**
    //  * @dev The constructor
    //  * @param _verifier the address of SNARK verifier for this contract
    //  * @param _hasher the address of Poseidon hash contract
    //  * @param _denomination transfer amount for each deposit
    //  * @param _merkleTreeHeight the height of deposits' Merkle Tree
    //  */
    constructor(
        IVerifier _verifier,
        IHasher _hasher,
        uint32 _merkleTreeHeight,
        MockToken _weth,
        MockToken _usdc
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        verifier = _verifier;
        Liquidated memory default_liquidated = Liquidated({
            liq_price: 0,
            timestamp: 0
        });
        for (uint256 i = 0; i < LIQUIDATED_ARRAY_NUMBER; i++) {
            liquidated_array[i] = default_liquidated;
        }
        weth = _weth;
        usdc = _usdc;
    }

    function flatten_liquidated_array() public view returns (uint256[] memory) {
        uint256[] memory output = new uint256[](LIQUIDATED_ARRAY_NUMBER * 2);
        for (uint256 i = 0; i < LIQUIDATED_ARRAY_NUMBER; i++) {
            output[2 * i] = liquidated_array[i].liq_price;
            output[2 * i + 1] = liquidated_array[i].timestamp;
        }
        return output;
    }

    function update_liquidated_array(
        uint8 index,
        uint256 _liq_price,
        uint256 _timestamp
    ) public {
        require(
            index < LIQUIDATED_ARRAY_NUMBER,
            "Index exceeds number of possible liquidated position buckets"
        );
        liquidated_array[index].liq_price = _liq_price;
        liquidated_array[index].timestamp = _timestamp;
    }

    modifier isWethOrUsdc(MockToken _token) {
        require(_token == weth || _token == usdc, "Token must be weth or usdc");
        _;
    }

    // TODO: ADD logic that allows us to add (liq_price, time) pair

    // Deposit funds (first time) into the contract
    function deposit(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes32 _proof,
        uint256 _lend_amt,
        MockToken _lend_token
    ) external payable nonReentrant isWethOrUsdc(_lend_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid root
        require(isKnownRoot(_root), "Cannot find your merkle root");

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );

        // Transfer token from user to contract
        require(
            _lend_token.transferFrom(msg.sender, address(this), _lend_amt),
            "Token lend failed"
        );

        uint256[] memory liq_array = flatten_liquidated_array();

        // Verify proof
        bytes32[] memory public_inputs = new bytes32[](6);
        public_inputs[0] = _new_note_hash;
        public_inputs[1] = _new_will_liq_price;
        public_inputs[2] = _new_timestamp;
        public_inputs[3] = _root;
        public_inputs[4] = liquidated_array[0].liq_price;
        public_inputs[5] = liquidated_array[0].timestamp;
        public_inputs[6] = liquidated_array[1].liq_price;
        public_inputs[7] = liquidated_array[1].timestamp;
        public_inputs[8] = liquidated_array[2].liq_price;
        public_inputs[9] = liquidated_array[2].timestamp;
        public_inputs[10] = liquidated_array[3].liq_price;
        public_inputs[11] = liquidated_array[3].timestamp;
        public_inputs[12] = liquidated_array[4].liq_price;
        public_inputs[13] = liquidated_array[4].timestamp;
        public_inputs[14] = liquidated_array[5].liq_price;
        public_inputs[15] = liquidated_array[5].timestamp;
        public_inputs[16] = liquidated_array[6].liq_price;
        public_inputs[17] = liquidated_array[6].timestamp;
        public_inputs[18] = liquidated_array[7].liq_price;
        public_inputs[19] = liquidated_array[7].timestamp;
        public_inputs[20] = liquidated_array[8].liq_price;
        public_inputs[21] = liquidated_array[8].timestamp;
        public_inputs[22] = liquidated_array[9].liq_price;
        public_inputs[23] = liquidated_array[9].timestamp;
        public_inputs[24] = _old_nullifier;
        public_inputs[25] = 0; // lend token out
        public_inputs[26] = 0; // borrow token out
        public_inputs[27] = _lend_amt; // lend token in
        public_inputs[28] = 0; // borrow token in
        require(
            verifier.verify(_proof, public_inputs),
            "Invalid deposit proof"
        );

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 insertedIndex = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // if old nullifier is not zero (new note), check if it is spent
        if (_old_nullifier != bytes32(0)) {
            require(
                nullifierHashes[_old_nullifier],
                "The note has been already spent"
            );
            nullifierHashes[_old_nullifier] = true;
        }

        emit Deposit(_new_note_hash, insertedIndex, _new_timestamp);
    }

    // borrow funds from the contract
    function borrow(
        uint256 _priWitness,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _commitment,
        address _recipient,
        uint256 _will_liq_price,
        uint256 _additional_borrow_amt
    ) external payable nonReentrant {
        require(
            !nullifierHashes[_nullifierHash],
            "The note has been already spent"
        );
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        // TODO: Do verify logic
        // require(
        //     verifier.verifyProof(
        //         [_priWitness],
        //         [
        //             uint256(_root),
        //             uint256(_nullifierHash),
        //             uint256(_commitment),
        //             uint256(_will_liq_price),
        //             uint256(_additional_borrow_amt),
        //             uint256(_liquidated_array)
        //         ]
        //     ),
        //     "Invalid borrow proof"
        // );

        nullifierHashes[_nullifierHash] = true;
        require(!commitments[_commitment], "The commitment has been submitted");
        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        require(
            borrow_token.transfer(_recipient, _additional_borrow_amt),
            "Token borrow failed"
        );
        emit Borrow(
            _recipient,
            _nullifierHash,
            _commitment,
            insertedIndex,
            block.timestamp
        );
    }

    // lend funds to the contract
    function lend(
        uint256 _priWitness,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _commitment,
        uint256 _will_liq_price,
        uint256 _additional_lend_amt
    ) external payable nonReentrant {
        require(
            !nullifierHashes[_nullifierHash],
            "The note has been already spent"
        );
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        // TODO: Do verify logic
        // require(
        //     verifier.verifyProof(
        //         [_priWitness],
        //         [
        //             uint256(_root),
        //             uint256(_nullifierHash),
        //             uint256(_commitment),
        //             uint256(_will_liq_price),
        //             uint256(_additional_borrow_amt),
        //             uint256(_liquidated_array)
        //         ]
        //     ),
        //     "Invalid borrow proof"
        // );

        nullifierHashes[_nullifierHash] = true;
        require(!commitments[_commitment], "The commitment has been submitted");
        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        require(
            lend_token.transferFrom(
                msg.sender,
                address(this),
                _additional_lend_amt
            ),
            "Token lend failed"
        );
        emit Lend(_nullifierHash, _commitment, insertedIndex, block.timestamp);
    }

    // repay what is borrowed back to the contract
    function repay(
        uint256 _priWitness,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _commitment,
        address _recipient,
        uint256 _will_liq_price,
        uint256 _repay_borrow_amt
    ) external payable nonReentrant {
        require(
            !nullifierHashes[_nullifierHash],
            "The note has been already spent"
        );
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        // TODO: Do verify logic
        // require(
        //     verifier.verifyProof(
        //         [_priWitness],
        //         [
        //             uint256(_root),
        //             uint256(_nullifierHash),
        //             uint256(_commitment),
        //             uint256(_will_liq_price),
        //             uint256(_additional_borrow_amt),
        //             uint256(_liquidated_array)
        //         ]
        //     ),
        //     "Invalid borrow proof"
        // );

        nullifierHashes[_nullifierHash] = true;
        require(!commitments[_commitment], "The commitment has been submitted");
        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        require(
            borrow_token.transferFrom(
                msg.sender,
                address(this),
                _repay_borrow_amt
            ),
            "Token repay failed"
        );
        emit Repay(_nullifierHash, _commitment, insertedIndex, block.timestamp);
    }

    // withdraw funds from the contract
    function withdraw(
        uint256 _priWitness,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _commitment,
        address _recipient,
        uint256 _will_liq_price,
        uint256 _withdraw_lend_amt
    ) external payable nonReentrant {
        require(
            !nullifierHashes[_nullifierHash],
            "The note has been already spent"
        );
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        // TODO: Do verify logic
        // require(
        //     verifier.verifyProof(
        //         [_priWitness],
        //         [
        //             uint256(_root),
        //             uint256(_nullifierHash),
        //             uint256(_commitment),
        //             uint256(_will_liq_price),
        //             uint256(_additional_borrow_amt),
        //             uint256(_liquidated_array)
        //         ]
        //     ),
        //     "Invalid borrow proof"
        // );

        nullifierHashes[_nullifierHash] = true;
        require(!commitments[_commitment], "The commitment has been submitted");
        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        require(
            lend_token.transfer(_recipient, _withdraw_lend_amt),
            "Token withdraw failed"
        );
        emit Withdraw(
            _recipient,
            _nullifierHash,
            _commitment,
            insertedIndex,
            block.timestamp
        );
    }

    /**
     * @dev whether a note is already spent
     */
    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    /**
     * @dev whether an array of notes is already spent
     */
    function isSpentArray(
        bytes32[] calldata _nullifierHashes
    ) external view returns (bool[] memory spent) {
        spent = new bool[](_nullifierHashes.length);
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            if (isSpent(_nullifierHashes[i])) {
                spent[i] = true;
            }
        }
    }
}
