//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NFT/IRandomRequester.sol";

interface INFT is IRandomRequester {
    function setBnbFee(uint bnbFee_) external;
    
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function spawn(address to, bool _isGenesis) external;
}