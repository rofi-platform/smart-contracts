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
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
	
	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

interface IPayRofi {
    function payRofi(address _sender, uint256 _amount) external;
}

contract UpgradeStar is IHero, Ownable {
    CNFT private cnft;
    
    INFT private nft;
    
    IPayRofi private payRofi;
    
    bytes32 public merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    mapping (uint256 => uint256) latestUpgradeStar;
    
    mapping (uint8 => uint256) upgradeStarFee;
    
    event StarUpgrade(uint256 heroId, uint256 subHeroId, uint8 newStar, bool isSuccess);
    
    uint nonce = 0;
    
    address public deadAddress = 0x05ea9701d37ca0db25993248e1d8461A8b50f24a;
    
    constructor(address _nft, address _cnft, address _payRofi) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
        payRofi = IPayRofi(_payRofi);
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
        uint8 currentStar = hero.star;
        uint256 fee = upgradeStarFee[currentStar];
        payRofi.payRofi(_msgSender(), fee);
        bool isSuccess = randomUpgrade(currentStar);
        if (isSuccess) {
            uint8 newStar = currentStar + 1;
            cnft.upgrade(_heroId, newStar);   
            latestUpgradeStar[_heroId] = block.number;
            nft.transferFrom(_msgSender(), deadAddress, _subHeroId);
            emit StarUpgrade(_heroId, _subHeroId, newStar, isSuccess);
        } else {
            emit StarUpgrade(_heroId, _subHeroId, currentStar, isSuccess);
        }
    }
    
    function randomUpgrade(uint8 _currentStar) internal returns (bool) {
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
    
    function updateNft(address _newAddress) external onlyOwner {
        nft = INFT(_newAddress);
    }
    
    function updateCnft(address _newAddress) external onlyOwner {
        cnft = CNFT(_newAddress);
    }
    
    function updatePayRofi(address _newAddress) external onlyOwner {
        payRofi = IPayRofi(_newAddress);
    }
    
    function updateFee(uint8[] memory _stars, uint256[] memory _fees) external onlyOwner {
        uint256 length = _stars.length;
        require(length == _fees.length, "params not correct");
        for (uint256 i = 0; i < length; i++) {
            uint8 _star = uint8(_stars[i]);
            upgradeStarFee[_star] = uint256(_fees[i]*10**18);
        }
    }
    
    function getFee(uint8 _currentStar) public view returns (uint256) {
        return upgradeStarFee[_currentStar];
    }
}