// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract StarFactory {
    function getStarFromRandomness(uint256 _randomness) external pure returns(uint8) {
        uint seed = _randomness % 100;
        if (seed < 60) {
            return 3;
        }
        if (seed < 80) {
            return 4;
        }
        if (seed < 95) {
            return 5;
        }
        return 6;
    }
}