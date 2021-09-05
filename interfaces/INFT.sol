//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IUseController.sol";
import "./NFT/IRandomRequester.sol";

interface INFT is IUseController, IRandomRequester {
    function setBnbFee(uint bnbFee_) external;
    
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function spawn(address to, bool _isGenesis) external;

    function latestTokenId() external view returns(uint);
}