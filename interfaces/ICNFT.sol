//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ICNFT {
    function getStarFromRandomness(uint256 _randomness) external returns (uint8);
    
    function getTotalHeroTypes() external returns (uint8);
}