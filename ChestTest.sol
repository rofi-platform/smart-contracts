// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ChestTest {
    using SafeMath for uint256;

    uint nonce = 0;

    function getRandomType(uint256 nonce) external view returns (uint8) {
        uint256 random = uint256(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
        uint8[3] memory itemTypes = [1,2,3];
        uint256 totalTypes = itemTypes.length;
        return itemTypes[uint256(random).mod(totalTypes)];
    }

    function getRandom(uint256 nonce) external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function getLength() external view returns (uint256) {
        uint8[3] memory itemTypes = [1,2,3];
        return uint256(itemTypes.length);
    }

    function getRandomWithMode(uint256 nonce) external view returns (uint256) {
        uint8[3] memory itemTypes = [1,2,3];
        return uint256(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1)))).mod(itemTypes.length);
    }
}