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
        _randomRequester = IRandomRequester(0x3114c0b418C3798339A765D32391440355DA9dDe);
    }
    
    function requestRandomNumber(uint256 _tokenId) external {
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        _randomRequester.submitRandomness(_tokenId, 29);
    }
    
    function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function setBnbFee(uint bnbFee_) external {
        _bnbFee = bnbFee_;
    }
}