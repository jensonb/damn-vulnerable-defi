// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWETH9 {
    function balanceOf(address user) external view returns (uint256);

    function allowance(address user, address spender)
        external
        view
        returns (uint256);

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function totalSupply() external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}
