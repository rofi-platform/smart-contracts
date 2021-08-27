// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface UpgraderInterface {
    function changeStar(uint256 _tokenId) external returns(uint8);
}