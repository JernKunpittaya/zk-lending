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

interface IVerifier {
    function verifyProof(
        // TODO: Fix _privWitness
        uint256[1] calldata _priWitness,
        uint256[6] calldata _pubSignals
    ) external view returns (bool);
}

abstract contract zkLend is MerkleTreeWithHistory, ReentrancyGuard {
    IVerifier public immutable verifier;
    // uint256 public denomination;

    mapping(bytes32 => bool) public nullifierHashes;
    // we store all commitments just to prevent accidental deposits with the same commitment
    mapping(bytes32 => bool) public commitments;

    event Deposit(bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    event Borrow(address to, bytes32 nullifierHash, bytes32 indexed commitment, uint32 leafIndex, uint256 timestamp);
    // event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    // /**
    //  * @dev The constructor
    //  * @param _verifier the address of SNARK verifier for this contract
    //  * @param _hasher the address of Poseidon hash contract
    //  * @param _denomination transfer amount for each deposit
    //  * @param _merkleTreeHeight the height of deposits' Merkle Tree
    //  */
    constructor(IVerifier _verifier, IHasher _hasher,  uint32 _merkleTreeHeight)
        MerkleTreeWithHistory(_merkleTreeHeight, _hasher)
    {
        verifier = _verifier;
    }

    /**
     * @dev Deposit funds into the contract. The caller must send (for ETH) or approve (for ERC20) value equal to or `denomination` of this instance.
     * @param _commitment the note commitment, which is PedersenHash(nullifier + secret)
     */
    function deposit(bytes32 _commitment, uint256 _lend_amt, uint256 _timestamp) external payable nonReentrant {
        require(!commitments[_commitment], "The commitment has been submitted");

        uint32 insertedIndex = _insert(_commitment);
        commitments[_commitment] = true;
        _processDeposit(_lend_amt);

        emit Deposit(_commitment, insertedIndex, _timestamp);
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processDeposit(uint256 _lend_amt) internal virtual;

    /**
     * @dev Withdraw a deposit from the contract. `proof` is a zkSNARK proof data, and input is an array of circuit public inputs
     * `input` array consists of:
     *   - merkle root of all deposits in the contract
     *   - hash of unique deposit nullifier to prevent double spends
     *   - the recipient of funds
     *   - optional fee that goes to the transaction sender (usually a relay)
     */
    function borrow(
        uint256 _priWitness,
        bytes32 _root,
        bytes32 _nullifierHash,
        bytes32 _commitment,
        address _recipient,
        uint256 _will_liq_price,
        uint256 _additional_borrow_amt,
        // TODO: Fix _liquidated_array
        uint256  _liquidated_array

    ) external payable nonReentrant {
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        // TODO: uncomment these when have actual logic
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one
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
        _processBorrow(_recipient, _additional_borrow_amt);
        emit Borrow(_recipient, _nullifierHash, _commitment,insertedIndex, block.timestamp);
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processBorrow(address _recipient, uint256 _additional_borrow_amt) internal virtual;

    /**
     * @dev whether a note is already spent
     */
    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifierHashes[_nullifierHash];
    }

    /**
     * @dev whether an array of notes is already spent
     */
    function isSpentArray(bytes32[] calldata _nullifierHashes) external view returns (bool[] memory spent) {
        spent = new bool[](_nullifierHashes.length);
        for (uint256 i = 0; i < _nullifierHashes.length; i++) {
            if (isSpent(_nullifierHashes[i])) {
                spent[i] = true;
            }
        }
    }
}
