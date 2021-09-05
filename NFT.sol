// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./modules/NFT/Random.sol";
import "./modules/UseController.sol";

contract NFT is ERC721, Ownable, UseController {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
    
    uint256 public latestTokenId;
    
    uint private nonce = 0;
    
    mapping(uint256 => Hero) internal heros;
    
    event Spawn(uint256 indexed tokenId, uint8 heroType, address to);
    event ChangeStar(uint256 indexed tokenId, uint8 star);
    
    Random public random;
    
    bytes32 merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    /*
        _initController: CNFT address
    */
    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _initController
    )
        ERC721(_name, _symbol)
        UseController(_manager, _initController)
    {
        random = new Random();
    }
    
    modifier onlyRandom {
        require(msg.sender == address(random), "require Random.");
        _;
    }
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }
    
    function setBnbFee(uint bnbFee_) external onlyController {
        random.setBnbFee(bnbFee_);
    }
    
    function upgrade(uint256 _tokenId, uint8 _star) public onlyController {
        Hero storage hero = heros[_tokenId];
        
        hero.star = _star;
        
        emit ChangeStar(_tokenId, _star);
    }

    function submitRandomness(uint _tokenId, uint _randomness) external onlyRandom {
        bytes32 dna = bytes32(keccak256(abi.encodePacked(_tokenId, _randomness)));
        uint8 star = _starFactory.getStarFromRandomness(_randomness);
        _initHero(_tokenId, star, dna);
    }
    
    function spawn(address to, bool _isGenesis) public onlyController {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        uint _randomNumber = _getRandomNumber();
        
        uint8 _totalHeroTypes = _getTotalHeroTypes();
        
        uint8 _heroType = uint8(_randomNumber.mod(_totalHeroTypes).add(1));
        
        heros[nextTokenId] = Hero({
            star: 0,
            heroType: _heroType,
            dna: '',
            isGenesis: _isGenesis,
            bornAt: block.timestamp
        });
        
        random.requestRandomNumber(nextTokenId);
        
        emit Spawn(nextTokenId, _heroType, to);
    }
    
    function updateMerkleRoots(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(bytes32[] memory _proof, bytes32 _leaf) public view returns (bool valid) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
    }
    
    function getHero(uint256 _tokenId) public view returns (Hero memory) {
        return heros[_tokenId];
    }
    
    function _getNextTokenId() private view returns (uint256) {
        return latestTokenId.add(1);
    }
    
    function _incrementTokenId() private {
        latestTokenId++;
    }
    
    function _getRandomNumber() private returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }
    
    function _initHero(uint256 _tokenId, uint8 _star, bytes32 _dna) private {
        Hero storage hero = heros[_tokenId];
        require(hero.star == 0, "require: star 0");

        hero.star = _star;
        hero.dna = _dna;

        emit ChangeStar(_tokenId, _star);
    }
    
}