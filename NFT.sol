// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./Random.sol";
import "./Manager.sol";
import "./StarFactory.sol";

contract NFT is ERC721, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct Hero {
        uint8 star;
        uint8 heroType;
        uint256 bornAt;
    }
    
    uint256 public latestTokenId;
    
    uint private nonce = 0;
    
    mapping(uint256 => Hero) internal heros;
    
    event Spawn(uint256 indexed tokenId, uint8 heroType, address to);
    event ChangeStar(uint256 indexed tokenId, uint8 star);
    
    Random public random;
    
    Manager public manager;
    
    StarFactory private _starFactory;

    bytes32 merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _manager
    ) ERC721(_name, _symbol)
    {
        random = new Random();
        manager = new Manager();
        _starFactory = new StarFactory();
    }
    
    modifier onlyManager {
        require(msg.sender == address(manager), "require Manager.");
        _;
    }
    
    modifier onlySpawner {
        require(manager.spawners(msg.sender), "require Spawner.");
        _;
    }
    
    modifier onlyUpgrader {
        require(manager.upgraders(msg.sender), "require Upgrader.");
        _;
    }
    
    modifier onlyRandom {
        require(msg.sender == address(random), "require Random.");
        _;
    }
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }
    
    function upgrade(uint256 _tokenId, uint8 _star) public onlyUpgrader {
        Hero storage hero = heros[_tokenId];
        
        hero.star = _star;
        
        emit ChangeStar(_tokenId, _star);
    }

    function submitRandomness(uint _tokenId, uint _randomness) external onlyRandom {
        uint8 star = _starFactory.getStarFromRandomness(_randomness);
        _initStar(_tokenId, star);
    }
    
    function spawn(address to) public onlySpawner {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        uint _randomNumber = _getRandomNumber();
        
        uint8 _totalHeroTypes = _getTotalHeroTypes();
        
        uint8 _heroType = uint8(_randomNumber.mod(_totalHeroTypes).add(1));
        
        heros[nextTokenId] = Hero({
            star: 0,
            heroType: _heroType,
            bornAt: block.timestamp
        });
        
        random.requestRandomNumber(nextTokenId);
        
        emit Spawn(nextTokenId, _heroType, to);
    }
    
    function multiSpawn(address to, uint amount) public onlySpawner {
        require(amount > 1, "require: multiple");
        for (uint256 index = 0; index < amount; index++) {
            spawn(to);
        }
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
    
    function _getTotalHeroTypes() private returns (uint8) {
        return manager.totalHeroTypes();
    }
    
    function _initStar(uint256 _tokenId, uint8 _star) private {
        Hero storage hero = heros[_tokenId];
        require(hero.star == 0, "require: star 0");

        hero.star = _star;

        emit ChangeStar(_tokenId, _star);
    }
    
    function changeStarFactory(address starFactory_) external onlyManager {
        _starFactory = StarFactory(starFactory_);
    }
}