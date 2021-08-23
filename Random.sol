// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RandomInterface.sol";

contract Random is VRFConsumerBase, RandomInterface {
    using SafeMath for uint256;
    
    uint256 private constant IN_PROGRESS = 42;

    bytes32 public keyHash;
    
    uint256 public fee;
    
    mapping(bytes32 => uint256) tokens;
    
    mapping(uint256 => uint256) results;
    
    event RandomNumberGenerated(uint256 tokenId);
    
    // constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee)
    //     VRFConsumerBase(
    //         _vrfCoordinator,
    //         _link
    //     ) public
    // {
    //     keyHash = _keyHash;
    //     fee = _fee;
    // }
    
    constructor()
        VRFConsumerBase(
            0xa555fC018435bef5A13C6c6870a9d4C11DEC329C,
            0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06
        ) public
    {
        keyHash = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
        fee = 0.1 * 10 ** 18;
    }
    
    function requestRandomNumber(uint256 tokenId) external override {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        tokens[requestId] = tokenId;
        results[tokenId] = IN_PROGRESS; 
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = tokens[requestId];
        results[tokenId] = randomness;
        emit RandomNumberGenerated(tokenId);
    }
    
    function getResultByTokenId(uint256 tokenId) external view override returns (uint256) {
        return results[tokenId];
    }
}