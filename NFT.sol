// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./modules/NFT/Random.sol";
import "./modules/UseController.sol";
import "./interfaces/controllers/ICNFT.sol";

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
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
    
    uint256 private _latestTokenId;
    
    uint private nonce = 0;
    
    mapping(uint256 => Hero) internal heros;
    
    event Spawn(uint256 indexed tokenId, address to);
    event InitHero(uint256 indexed tokenId, uint8 star, uint8 heroType, bytes32 dna);
    event ChangeStar(uint256 indexed tokenId, uint8 star);
    event NewRandom(address _newRandom);
    
    Random private _random;
    
    bytes32 merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    /*
        _initController: CNFT address
    */
    constructor(
        string memory _name,
        string memory _symbol,
        address _manager
    )
        BannableERC721(_name, _symbol)
        UseController(_manager)
    {
        _random = new Random();
    }
    
    modifier onlyRandom {
        require(msg.sender == address(_random), "require Random.");
        _;
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
    
    function _initHero(uint256 _tokenId, uint8 _star, bytes32 _dna, uint8 _heroType) private {
        Hero storage hero = heros[_tokenId];
        require(hero.heroType == 0, "require: heroType 0");

        if (hero.star == 0) {
            hero.star = _star;
        }
        hero.dna = _dna;
        hero.heroType = _heroType;

        emit InitHero(_tokenId, _star, _heroType, _dna);
    }

    /*
        public
    */

    function ban(uint tokenId_, string memory reason_) external onlyController {
        _ban(tokenId_, reason_);
    }

    function unban(uint tokenId_, string memory reason_) external onlyController {
        _unban(tokenId_, reason_);
    }
    
    function setBnbFee(uint bnbFee_) external onlyController {
        _random.setBnbFee(bnbFee_);
    }
    
    function upgrade(uint256 _tokenId, uint8 _star) public onlyController {
        Hero storage hero = heros[_tokenId];
        
        hero.star = _star;
        
        emit ChangeStar(_tokenId, _star);
    }

    function submitRandomness(uint _tokenId, uint _randomness) external onlyRandom {
        bytes32 dna = bytes32(keccak256(abi.encodePacked(_tokenId, _randomness)));
        uint8 star = ICNFT(controller()).getStarFromRandomness(_randomness);
        uint8 totalHeroTypes = ICNFT(controller()).getTotalHeroTypes();
        uint8 heroType = uint8(_randomness.mod(totalHeroTypes).add(1));
        _initHero(_tokenId, star, dna, heroType);
    }
    
    function spawn(address to, bool _isGenesis, uint8 _star) public onlyController {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        heros[nextTokenId] = Hero({
            star: _star,
            heroType: 0,
            dna: '',
            isGenesis: _isGenesis,
            bornAt: block.timestamp
        });
        
        _random.requestRandomNumber(nextTokenId);
        
        emit Spawn(nextTokenId, to);
    }

    function mint(address to, bool _isGenesis, uint8 _star, bytes32 _dna, uint8 _heroType) public onlyController {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        heros[nextTokenId] = Hero({
            star: _star,
            heroType: _heroType,
            dna: _dna,
            isGenesis: _isGenesis,
            bornAt: block.timestamp
        });

        emit InitHero(nextTokenId, _star, _heroType, _dna);
    }
    
    function updateMerkleRoots(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }

    function updateRandom(address payable _newRandom) public onlyOwner {
        _random = Random(_newRandom);

        emit NewRandom(_newRandom);
    }
    
    function verifyMerkleProof(bytes32[] memory _proof, bytes32 _leaf) public view returns (bool valid) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
    
    function getHero(uint256 _tokenId) public view returns (Hero memory) {
        return heros[_tokenId];
    }

    function random()
        external
        view
        returns(address)
    {
        return address(_random);
    }

    function latestTokenId()
        external
        view
        returns(uint)
    {
        return _latestTokenId;
    }
}