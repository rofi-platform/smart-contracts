// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandom {
    function requestRandomNumber(uint256 tokenId) external;
    
    function setBnbFee(uint bnbFee_) external;
    
    function getResultByTokenId(uint256 tokenId) external view returns (uint256);
}