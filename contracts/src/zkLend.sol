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
import {HonkVerifier} from "./Verifier.sol";

contract zkLend is MerkleTreeWithHistory, ReentrancyGuard {
    HonkVerifier public immutable verifier;
    MockToken public lend_token;
    MockToken public borrow_token;
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
        IHasher _hasher,
        uint32 _merkleTreeHeight,
        MockToken _lend_token,
        MockToken _borrow_token
    ) MerkleTreeWithHistory(_merkleTreeHeight, _hasher) {
        verifier = new HonkVerifier();
        Liquidated memory default_liquidated = Liquidated({
            liq_price: 0,
            timestamp: 0
        });
        for (uint256 i = 0; i < LIQUIDATED_ARRAY_NUMBER; i++) {
            liquidated_array[i] = default_liquidated;
        }
        lend_token = _lend_token;
        borrow_token = _borrow_token;
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

    // TODO: ADD logic that allows us to add (liq_price, time) pair

    // Deposit funds (first time) into the contract
    function deposit(
        bytes32 _commitment,
        uint256 _lend_amt,
        uint256 _timestamp
    ) external payable nonReentrant {
        require(!commitments[_commitment], "The commitment has been submitted");

        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        require(
            lend_token.transferFrom(msg.sender, address(this), _lend_amt),
            "Token lend failed"
        );
        emit Deposit(_commitment, insertedIndex, _timestamp);
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
