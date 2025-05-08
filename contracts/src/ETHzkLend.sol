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

import "./zkLend.sol";
import {MockToken} from "src/MockToken.sol";

contract ETHzkLend is zkLend {
    constructor(IVerifier _verifier, IHasher _hasher, uint32 _merkleTreeHeight)
        zkLend(_verifier, _hasher, _merkleTreeHeight)
    {}

    function _processDeposit(uint256 _lend_amt) internal override {
        require(msg.value == _lend_amt, "Please lend the same number of ETH as you stated");
    }

    function _processBorrow(address _recipient, uint256 _additional_borrow_amt, MockToken _token) internal override {
        // sanity checks
        require(msg.value == 0, "Message value is supposed to be zero for ETH instance");

        // (bool success,) = _recipient.call{value: _additional_borrow_amt}("");
        // require(success, "borrow fund to _recipient did not go thru");
        require(_token.transfer(_recipient, _additional_borrow_amt), "Token borrow failed");

    }
}
