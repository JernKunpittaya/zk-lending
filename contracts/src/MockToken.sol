// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private _customDecimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply) ERC20(_name, _symbol) {
        _customDecimals = _decimals;
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _customDecimals;
    }
}
