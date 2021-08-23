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
    
    struct Robo {
        uint8 tribe;
        uint256 exp;
        uint256 bornAt;
    }
    
    uint256 public latestTokenId;
    
    mapping(uint256 => Robo) internal robos;
    
    event Spawning(uint256 indexed tokenId);
    event Evolve(uint256 indexed tokenId, uint8 tribe);
    event Exp(uint256 indexed tokenId, address onwer, uint256 exp);
    
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
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }
    
    function spawn(address to) public onlySpawner {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to, nextTokenId);
        
        robos[nextTokenId] = Robo({
            tribe: 0, // Egg
            exp: 0,
            bornAt: block.timestamp
        });
        
        random.requestRandomNumber(nextTokenId);
        
        emit Spawning(nextTokenId);
    }
    
    function multiSpawn(address to, uint amount) public onlySpawner {
        require(amount > 1, "require: multiple");
        for (uint256 index = 0; index < amount; index++) {
            spawn(to);
        }
    }
    
    function exp(uint256 _tokenId, address _owner, uint256 _exp) public onlySpawner {
        require(_exp > 0, "require: non zero exp");
        Robo storage robo = robos[_tokenId];
        robo.exp = robo.exp.add(_exp);
        emit Exp(_tokenId, _owner, _exp);
    }
    
    function evolve(uint256 _tokenId, address _owner) public onlySpawner {
        require(ownerOf(_tokenId) == _owner, "require: owner");
        Robo storage robo = robos[_tokenId];
        require(robo.tribe == 0, "require: tribe 0");
        
        uint256 randomNumber = random.getResultByTokenId(_tokenId);
        require(randomNumber != 42, "required: not generated");
        
        uint8 tribe = uint8(randomNumber.mod(6).add(1));
        
        robo.bornAt = block.timestamp;
        robo.tribe = tribe;
        
        emit Evolve(_tokenId, tribe);
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
}