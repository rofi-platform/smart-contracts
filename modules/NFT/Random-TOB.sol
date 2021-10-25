// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface NFT {
    function submitRandomness(uint _tokenId, uint _randomness) external;
}

contract Random_TOB is Ownable {
    NFT public nft;
    
    uint nonce = 0;
    
    receive() external payable {
    }
    
    constructor(address _nft) {
        nft = NFT(_nft);
    }
    
    function requestRandomNumber(uint256 _tokenId) external {
        require(msg.sender == address(nft), "Only NFT contract call");
        uint randomness = getRandomNumber();
        nft.submitRandomness(_tokenId, randomness);
    }
    
    function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }
    
    function updateNft(address _nft) external onlyOwner {
        nft = NFT(_nft);
    }
}