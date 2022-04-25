// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./modules/UseController.sol";

contract BannableERC721  is ERC721 {
    event Ban(uint indexed tokenId, string reason);
    event Unban(uint indexed tokenId, string reason);

    modifier onlyNotBanned(
        uint tokenId_
    )
    {
        require(!_isBanned[tokenId_], "BannableERC721: banned!");
        _;
    }

    modifier onlyBanned(
        uint tokenId_
    )
    {
        require(_isBanned[tokenId_], "BannableERC721: not banned!");
        _;
    }

    mapping(uint => bool) private _isBanned;

    constructor(
        string memory _name,
        string memory _symbol
    )
        ERC721(_name, _symbol)
    {
    }

    function _ban(
        uint tokenId_,
        string memory reason_
    )
        internal
        onlyNotBanned(tokenId_)
    {
        _isBanned[tokenId_] = true;
        emit Ban(tokenId_, reason_);
    }

    function _unban(
        uint tokenId_,
        string memory reason_
    )
        internal
        onlyBanned(tokenId_)
    {
        _isBanned[tokenId_] = false;
        emit Unban(tokenId_, reason_);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override
        onlyNotBanned(tokenId)
    {
        super._transfer(from, to, tokenId);
    }

    /*
        public
    */

    function isBanned(
        uint tokenId_
    )
        public
        view
        returns(bool)
    {
        return _isBanned[tokenId_];
    }
}

contract NFT is BannableERC721, Ownable, UseController {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 class;
        uint256 plantId;
        uint256 bornAt;
    }
    
    uint256 private _latestTokenId;
    
    uint private nonce = 0;

    uint8 public totalClass;
    
    mapping(uint256 => Hero) internal heros;

    mapping (uint8 => uint256[]) public planIds;
    
    event InitHero(uint256 indexed tokenId, address to, uint8 star, uint8 rarity, uint8 class, uint256 plantId);
    event ChangeStar(uint256 indexed tokenId, uint8 star);
        
    constructor(
        string memory _name,
        string memory _symbol,
        address _manager
    )
        BannableERC721(_name, _symbol)
        UseController(_manager)
    {

    }
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }

    function _getNextTokenId() private view returns (uint256) {
        return _latestTokenId.add(1);
    }
    
    function _incrementTokenId() private {
        _latestTokenId++;
    }

    function ban(uint tokenId_, string memory reason_) external onlyController {
        _ban(tokenId_, reason_);
    }

    function unban(uint tokenId_, string memory reason_) external onlyController {
        _unban(tokenId_, reason_);
    }
    
    function upgrade(uint256 _tokenId, uint8 _star) public onlyController {
        Hero storage hero = heros[_tokenId];
        
        hero.star = _star;
        
        emit ChangeStar(_tokenId, _star);
    }

    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _class, uint256 _plantId) public onlyController {
        uint256 nextTokenId = _getNextTokenId();
        _mint(_to, nextTokenId);
        
        heros[nextTokenId] = Hero({
            star: _star,
            rarity: _rarity,
            class: _class,
            plantId: _plantId,
            bornAt: block.timestamp
        });

        emit InitHero(nextTokenId, _to, _star, _rarity, _class, _plantId);
    }
    
    function getHero(uint256 _tokenId) public view returns (Hero memory) {
        return heros[_tokenId];
    }

    function getPlanIds(uint8 _class) public view returns (uint256[] memory) {
        return planIds[_class];
    }

    function updatePlanIds(uint8 _class, uint256[] memory _plantIds) public onlyController {
        planIds[_class] = _plantIds;
    }

    function getTotalClass() public view returns (uint8) {
        return totalClass;
    }

    function updateTotalClass(uint8 _totalClass) public onlyController {
        totalClass = _totalClass;
    }

    function latestTokenId() external view returns(uint) {
        return _latestTokenId;
    }
}