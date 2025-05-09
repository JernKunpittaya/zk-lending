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
        bytes32 nullifierHash,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Borrow(
        bytes32 indexed commitment,
        address to,
        bytes32 nullifierHash,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Repay(
        bytes32 indexed commitment,
        bytes32 nullifierHash,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Withdraw(
        bytes32 indexed commitment,
        address to,
        bytes32 nullifierHash,
        uint32 leafIndex,
        uint256 timestamp
    );
    event Claim(
        bytes32 indexed commitment,
        address to,
        bytes32 nullifierHash,
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

    function constructPublicInputs(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        uint256 _lend_token_out,
        uint256 _borrow_token_out,
        uint256 _lend_token_in,
        uint256 _borrow_token_in
    ) public view returns (bytes32[] memory) {
        bytes32[] memory public_inputs = new bytes32[](6);
        public_inputs[0] = _new_note_hash;
        public_inputs[1] = _new_will_liq_price;
        public_inputs[2] = bytes32(_new_timestamp);
        public_inputs[3] = _root;
        public_inputs[4] = bytes32(liquidated_array[0].liq_price);
        public_inputs[5] = bytes32(liquidated_array[0].timestamp);
        public_inputs[6] = bytes32(liquidated_array[1].liq_price);
        public_inputs[7] = bytes32(liquidated_array[1].timestamp);
        public_inputs[8] = bytes32(liquidated_array[2].liq_price);
        public_inputs[9] = bytes32(liquidated_array[2].timestamp);
        public_inputs[10] = bytes32(liquidated_array[3].liq_price);
        public_inputs[11] = bytes32(liquidated_array[3].timestamp);
        public_inputs[12] = bytes32(liquidated_array[4].liq_price);
        public_inputs[13] = bytes32(liquidated_array[4].timestamp);
        public_inputs[14] = bytes32(liquidated_array[5].liq_price);
        public_inputs[15] = bytes32(liquidated_array[5].timestamp);
        public_inputs[16] = bytes32(liquidated_array[6].liq_price);
        public_inputs[17] = bytes32(liquidated_array[6].timestamp);
        public_inputs[18] = bytes32(liquidated_array[7].liq_price);
        public_inputs[19] = bytes32(liquidated_array[7].timestamp);
        public_inputs[20] = bytes32(liquidated_array[8].liq_price);
        public_inputs[21] = bytes32(liquidated_array[8].timestamp);
        public_inputs[22] = bytes32(liquidated_array[9].liq_price);
        public_inputs[23] = bytes32(liquidated_array[9].timestamp);
        public_inputs[24] = _old_nullifier;
        public_inputs[25] = bytes32(_lend_token_out);
        public_inputs[26] = bytes32(_borrow_token_out);
        public_inputs[27] = bytes32(_lend_token_in);
        public_inputs[28] = bytes32(_borrow_token_in);
        return public_inputs;
    }

    function deposit(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes calldata _proof,
        uint256 _lend_amt,
        MockToken _lend_token
    ) external payable nonReentrant isWethOrUsdc(_lend_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );
        require(
            _new_timestamp <= block.timestamp,
            "Invalid timestamp, must be in the past"
        );

        // Transfer token from user to contract
        require(
            _lend_token.transferFrom(msg.sender, address(this), _lend_amt),
            "Token lend failed"
        );

        // Verify proof
        bytes32[] memory public_inputs = constructPublicInputs(
            _new_note_hash,
            _new_will_liq_price,
            _new_timestamp,
            _root,
            _old_nullifier,
            0,
            0,
            _lend_amt,
            0
        );
        require(
            verifier.verify(_proof, public_inputs),
            "Invalid deposit proof"
        );

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 inserted_index = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // if old nullifier is not zero (new note), check if it is spent
        if (_old_nullifier != bytes32(0)) {
            // Check valid root
            require(isKnownRoot(_root), "Cannot find your merkle root");

            // Check old note nullifier
            require(
                nullifierHashes[_old_nullifier],
                "The note has been already spent"
            );
            nullifierHashes[_old_nullifier] = true;
        }

        emit Deposit(
            _new_note_hash,
            _old_nullifier,
            inserted_index,
            _new_timestamp
        );
    }

    function borrow(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes calldata _proof,
        uint256 _borrow_amt,
        MockToken _borrow_token,
        address _to
    ) external payable nonReentrant isWethOrUsdc(_borrow_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );
        require(
            _new_timestamp <= block.timestamp,
            "Invalid timestamp, must be in the past"
        );

        _borrow_token.transfer(_to, _borrow_amt);

        // Verify proof
        bytes32[] memory public_inputs = constructPublicInputs(
            _new_note_hash,
            _new_will_liq_price,
            _new_timestamp,
            _root,
            _old_nullifier,
            0,
            _borrow_amt,
            0,
            0
        );
        require(verifier.verify(_proof, public_inputs), "Invalid borrow proof");

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 inserted_index = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // Check valid root
        require(isKnownRoot(_root), "Cannot find your merkle root");

        // Check old nullifier is not zero
        require(_old_nullifier != bytes32(0), "Old nullifier must not be zero");

        // Check old note nullifier
        require(
            nullifierHashes[_old_nullifier],
            "The note has been already spent"
        );
        nullifierHashes[_old_nullifier] = true;

        emit Borrow(
            _new_note_hash,
            _to,
            _old_nullifier,
            inserted_index,
            _new_timestamp
        );
    }

    function repay(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes calldata _proof,
        uint256 _repay_amt,
        MockToken _repay_token
    ) external payable nonReentrant isWethOrUsdc(_repay_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );
        require(
            _new_timestamp <= block.timestamp,
            "Invalid timestamp, must be in the past"
        );

        _repay_token.transferFrom(msg.sender, address(this), _repay_amt);

        // Verify proof
        bytes32[] memory public_inputs = constructPublicInputs(
            _new_note_hash,
            _new_will_liq_price,
            _new_timestamp,
            _root,
            _old_nullifier,
            0,
            0,
            0,
            _repay_amt
        );
        require(verifier.verify(_proof, public_inputs), "Invalid repay proof");

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 inserted_index = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // Check valid root
        require(isKnownRoot(_root), "Cannot find your merkle root");

        // Check old nullifier is not zero
        require(_old_nullifier != bytes32(0), "Old nullifier must not be zero");

        // Check old note nullifier
        require(
            nullifierHashes[_old_nullifier],
            "The note has been already spent"
        );
        nullifierHashes[_old_nullifier] = true;

        emit Repay(
            _new_note_hash,
            _old_nullifier,
            inserted_index,
            _new_timestamp
        );
    }

    function withdraw(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes calldata _proof,
        uint256 _withdraw_amt,
        MockToken _withdraw_token,
        address _to
    ) external payable nonReentrant isWethOrUsdc(_withdraw_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );
        require(
            _new_timestamp <= block.timestamp,
            "Invalid timestamp, must be in the past"
        );

        _withdraw_token.transferFrom(address(this), _to, _withdraw_amt);

        // Verify proof
        bytes32[] memory public_inputs = constructPublicInputs(
            _new_note_hash,
            _new_will_liq_price,
            _new_timestamp,
            _root,
            _old_nullifier,
            _withdraw_amt,
            0,
            0,
            0
        );
        require(
            verifier.verify(_proof, public_inputs),
            "Invalid withdraw proof"
        );

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 inserted_index = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // Check valid root
        require(isKnownRoot(_root), "Cannot find your merkle root");

        // Check old nullifier is not zero
        require(_old_nullifier != bytes32(0), "Old nullifier must not be zero");

        // Check old note nullifier
        require(
            nullifierHashes[_old_nullifier],
            "The note has been already spent"
        );
        nullifierHashes[_old_nullifier] = true;

        emit Withdraw(
            _new_note_hash,
            _to,
            _old_nullifier,
            inserted_index,
            _new_timestamp
        );
    }

    function claim(
        bytes32 _new_note_hash,
        bytes32 _new_will_liq_price,
        uint256 _new_timestamp,
        bytes32 _root,
        bytes32 _old_nullifier,
        bytes calldata _proof,
        uint256 _claim_amt,
        MockToken _claim_token,
        address _to
    ) external payable nonReentrant isWethOrUsdc(_claim_token) {
        // TODO: check _new_will_liq_price is valid from some price oracle

        // Check valid timestamp
        require(
            _new_timestamp > block.timestamp - 5 minutes,
            "Invalid timestamp, must be within 5 minutes of proof generation"
        );
        require(
            _new_timestamp <= block.timestamp,
            "Invalid timestamp, must be in the past"
        );

        _claim_token.transferFrom(address(this), _to, _claim_amt);

        // Verify proof
        bytes32[] memory public_inputs = constructPublicInputs(
            _new_note_hash,
            _new_will_liq_price,
            _new_timestamp,
            _root,
            _old_nullifier,
            0,
            _claim_amt,
            0,
            0
        );
        require(verifier.verify(_proof, public_inputs), "Invalid claim proof");

        // New note commitment add to tree
        require(
            !commitments[_new_note_hash],
            "The commitment has been submitted"
        );
        uint32 inserted_index = _insert(_new_note_hash);
        commitments[_new_note_hash] = true;

        // Check valid root
        require(isKnownRoot(_root), "Cannot find your merkle root");

        // Check old nullifier is not zero
        require(_old_nullifier != bytes32(0), "Old nullifier must not be zero");

        // Check old note nullifier
        require(
            nullifierHashes[_old_nullifier],
            "The note has been already spent"
        );
        nullifierHashes[_old_nullifier] = true;

        emit Withdraw(
            _new_note_hash,
            _to,
            _old_nullifier,
            inserted_index,
            _new_timestamp
        );
    }
}
