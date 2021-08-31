// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./ERC721.sol";
import "./RandomInterface.sol";

contract NFT is ERC721, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct Hero {
        bool isInitSale;
        uint8 star;
        uint8 heroType;
        uint256 exp;
        uint256 bornAt;
    }
    
    uint256 public latestTokenId;
    
    uint nonce = 0;
    
    mapping(uint256 => Hero) internal heros;
    
    event Spawn(uint256 indexed tokenId, address to);
    
    event Evolve(uint256 indexed tokenId, uint8 tribe);
    event Exp(uint256 indexed tokenId, address onwer, uint256 exp);
    event ChangeStar(uint256 indexed tokenId, uint8 star);
    
    RandomInterface public random;
    
    bytes32 merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _random
    ) ERC721(_name, _symbol, _manager)
    {
        random = RandomInterface(_random);
    }
    
    modifier onlySpawner {
        require(manager.spawners(msg.sender), "require Spawner.");
        _;
    }
    
    modifier onlyUpgrader {
        require(manager.upgraders(msg.sender), "require Upgrader.");
        _;
    }
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }
    
    function spawn(address to) public onlySpawner {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        uint _randomNumber = _getRandomNumber();
        
        uint8 _totalHeroTypes = _getTotalHeroTypes();
        
        uint8 _heroType = uint8(_randomNumber.mod(_totalHeroTypes).add(1));
        
        heros[nextTokenId] = Hero({
            isInitSale: false,
            star: 0,
            heroType: _heroType,
            exp: 0,
            bornAt: block.timestamp
        });
        
        random.requestRandomNumber(nextTokenId);
        
        emit Spawn(nextTokenId, to);
    }
    
    function spawn(address to, bool _isInitSale) public onlySpawner {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        uint _randomNumber = _getRandomNumber();
        
        uint8 _totalHeroTypes = _getTotalHeroTypes();
        
        uint8 _heroType = uint8(_randomNumber.mod(_totalHeroTypes).add(1));
        
        heros[nextTokenId] = Hero({
            isInitSale: _isInitSale,
            star: 1,
            heroType: _heroType,
            exp: 0,
            bornAt: block.timestamp
        });
        
        random.requestRandomNumber(nextTokenId);
        
        emit Spawn(nextTokenId, to);
    }
    
    function multiSpawn(address to, uint amount) public onlySpawner {
        require(amount > 1, "require: multiple");
        for (uint256 index = 0; index < amount; index++) {
            spawn(to);
        }
    }
    
    function exp(uint256 _tokenId, address _owner, uint256 _exp) public onlySpawner {
        require(_exp > 0, "require: non zero exp");
        Hero storage hero = heros[_tokenId];
        hero.exp = hero.exp.add(_exp);
        emit Exp(_tokenId, _owner, _exp);
    }
    
    function evolve(uint256 _tokenId, address _owner) public onlySpawner {
        require(ownerOf(_tokenId) == _owner, "require: owner");
        Hero storage hero = heros[_tokenId];
        require(hero.tribe == 0, "require: tribe 0");
        
        uint256 randomNumber = random.getResultByTokenId(_tokenId);
        require(randomNumber != 42, "required: not generated");
        
        uint8 tribe = uint8(randomNumber.mod(6).add(1));
        
        hero.bornAt = block.timestamp;
        hero.tribe = tribe;
        
        emit Evolve(_tokenId, tribe);
    }
    
    function changeStar(uint256 _tokenId, uint8 _star) public onlyUpgrader {
        Hero storage hero = heros[_tokenId];
        
        hero.star = _star;
        
        emit ChangeStar(_tokenId, _star);
    }
    
    function updateMerkleRoots(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(bytes32[] memory _proof, bytes32 _leaf) public view returns (bool valid) {
        return MerkleProof.verify(_proof, merkleRoot, _leaf);
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
    
    function _getBiggestStar() private returns (uint8) {
        return manager.biggestStar();
    }
}