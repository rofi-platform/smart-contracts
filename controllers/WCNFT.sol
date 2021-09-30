//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IHero {
	struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}

interface CNFT {
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function transferOwnership(address newOwner) external;
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
	
	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

contract WCNFT is IHero, Ownable {
    CNFT public cnft;
    
    INFT public nft;
    
    mapping (address => bool) _upgraders;
    
    bytes32 public merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    mapping (uint256 => uint256) latestUpgradeStar;
    
    event UpgradeStar(uint256 heroId, uint256 subHeroId, uint8 newStar, bool isSuccess);
    
    uint nonce = 0;
    
    address public deadAddress = 0x05ea9701d37ca0db25993248e1d8461A8b50f24a;
    
    modifier onlyUpgrader {
        require(_upgraders[msg.sender] || owner() == msg.sender, "require Upgrader");
        _;
    }
    
    constructor(address _nft, address _cnft) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
    }
    
    function upgradeStar(uint256 _heroId, uint8 _level, bytes32[] memory _proof, uint256 _subHeroId) external {
        require(nft.ownerOf(_heroId) == _msgSender(), "not owner");
        require(nft.ownerOf(_subHeroId) == _msgSender(), "not owner");
        Hero memory hero = nft.getHero(_heroId);
        Hero memory subHero = nft.getHero(_subHeroId);
        require(hero.star == subHero.star, "must same star");
        require(hero.heroType == subHero.heroType, "must same hero type");
        require(latestUpgradeStar[_heroId] == 0 || (block.number - latestUpgradeStar[_heroId]) >= 300, "must wait a least 300 blocks");
        require(_level == 30, "level must be 30");
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _level));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "proof not valid");
        bool isSuccess = randomUpgrade(hero.star);
        uint8 newStar = hero.star;
        if (isSuccess) {
            uint8 newStar = hero.star + 1;
            cnft.upgrade(_heroId, newStar);   
            latestUpgradeStar[_heroId] = block.number;
            nft.transferFrom(_msgSender(), deadAddress, _subHeroId);
        }
        
        emit UpgradeStar(_heroId, _subHeroId, newStar, isSuccess);
    }
    
    function randomUpgrade(uint8 _currentStar) internal returns (bool) {
        if (_currentStar == 1) {
            return true;
        }
        uint random = getRandomNumber();
        uint seed = random % 100;
        uint successRate = getSuccessRate(_currentStar);
        if (seed < successRate) {
            return true;
        }
        return false;
    }
    
    function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }
    
    function getSuccessRate(uint8 _currentStar) internal returns (uint) {
        if (_currentStar == 1) {
            return 100;
        }
        if (_currentStar == 2) {
            return 50;
        }
        if (_currentStar == 3) {
            return 25;
        }
        if (_currentStar == 4) {
            return 12;
        }
        return 6;
    }
    
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(uint256 _heroId, uint8 _level, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _level));
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }
    
    function upgraders(address _address) external view returns (bool) {
        return _upgraders[_address];
    }
    
    function addUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = true;
    }
    
    function removeUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = false;
    }
    
    function transferCNFTOwnership(address newOwner) public onlyOwner {
        cnft.transferOwnership(newOwner);
    }
}