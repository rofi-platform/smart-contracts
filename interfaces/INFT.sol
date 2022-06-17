//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IUseController.sol";
import "./IHero.sol";
import "./NFT/IRandomRequester.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFT is IUseController, IRandomRequester, IERC721, IHero {
    function ban(uint tokenId_, string memory reason_) external;

    function unban(uint tokenId_, string memory reason_) external;
    
    function upgrade(uint256 _tokenId, uint8 _star) external;

    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _class, uint256 _plantId) external;

    function latestTokenId() external view returns(uint);
    
    function getHero(uint256 _tokenId) external view returns (Hero memory);

    function getTotalClass() external view returns (uint8);

    function updateTotalClass(uint8 _totalClass) external;

    function getPlanIds(uint8 _plantClass, uint8 _rarity) external view returns (uint256[] memory);

    function updatePlanIds(uint8 _plantClass, uint8 _rarity, uint256[] memory _plantIds) external;
}