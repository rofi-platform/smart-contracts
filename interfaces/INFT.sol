//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IUseController.sol";
import "./IHero.sol";
import "./NFT/IRandomRequester.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFT is IUseController, IRandomRequester, IERC721, IHero {
    function ban(uint tokenId_, string memory reason_) external;

    function unban(uint tokenId_, string memory reason_) external;

    function setBnbFee(uint bnbFee_) external;
    
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function spawn(address to, bool _isGenesis, uint8 _star) external;

    function latestTokenId() external view returns(uint);
    
    function getHero(uint256 _tokenId) external view returns (Hero memory);
}