// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private immutable tokenDecimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        tokenDecimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }
}

contract FeeOnTransferMock is MockERC20 {
    constructor() MockERC20("Fee token", "FEE", 6) { }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            uint256 fee = value / 100;
            super._update(from, address(0), fee);
            super._update(from, to, value - fee);
        } else {
            super._update(from, to, value);
        }
    }
}

contract RestrictedTokenMock is MockERC20 {
    mapping(address => bool) public restricted;

    constructor() MockERC20("Restricted EUR", "rEUR", 6) { }

    function setRestricted(address account, bool value) external {
        restricted[account] = value;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!restricted[from] && !restricted[to], "RESTRICTED");
        super._update(from, to, value);
    }
}
