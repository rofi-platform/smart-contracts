// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../interfaces/NFT/IRandomRequester.sol";

contract Random is Ownable {
    uint nonce = 0;

    uint public _bnbFee;

    IRandomRequester private _randomRequester;
    
    receive() external payable {
    }
    
    constructor() {
        _randomRequester = IRandomRequester(msg.sender);
    }
    
    function requestRandomNumber(uint256 _tokenId) external {
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        uint randomness = getRandomNumber();
        _randomRequester.submitRandomness(_tokenId, randomness);
    }
    
    function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function setBnbFee(uint bnbFee_) external {
        _bnbFee = bnbFee_;
    }
}