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

interface IBEP20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract UpgradeStar is IHero, Ownable {
    CNFT public cnft;
    
    INFT public nft;
                
    mapping (uint8 => uint256) upgradeStarFee;

    struct Requirement {
        address token1;
        uint256 token1Require;
        address token2;
        uint256 token2Require;
        uint8 numberHeroRequire;
        uint8 successPercent;
    }

    mapping (uint8 => Requirement) requirements;
    
    event StarUpgrade(uint256 heroId, uint8 newStar, bool isSuccess);
        
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

    uint nonce = 0;

    bytes32 public merkleRoot;

    event MerkleRootUpdated(bytes32 merkleRoot);
    
    constructor(address _nft, address _cnft, address _feeAddress) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
        feeAddress = _feeAddress;
    }

    function upgradeStar(uint256[] memory _heroIds, uint8 _level, bytes32[] memory _proof) external {
        uint256 length = _heroIds.length;
        require(length > 1, "require: at least 2 heroes");
        require(_level == 30, "level must be 30");
        require(MerkleProof.verify(_proof, merkleRoot, bytes32(keccak256(abi.encodePacked(_heroIds[0], _level)))), "data is outdated or invalid");
        uint8[] memory stars = new uint8[](length);
        bool sameStar = true;
        bool isOwner = true;
        for (uint256 i = 0; i < length; i++) {
            if (nft.ownerOf(_heroIds[i]) != _msgSender()) {
                isOwner = false;
            }
            Hero memory hero = nft.getHero(_heroIds[i]);
            uint8 star = hero.star;
            stars[i] = star;
        }
        uint8 currentStar = stars[0];
        for (uint256 j = 0; j < stars.length - 1; j++) {
            if (stars[j] != stars[j + 1]) {
                sameStar = false;
            }
        }
        require(isOwner, "require: must be owner");
        require(sameStar, "require: must same star");
        Requirement memory requirement = requirements[currentStar];
        require(length == requirement.numberHeroRequire, "require: number of heroes not correct");
        IBEP20(requirement.token1).transferFrom(_msgSender(), feeAddress, requirement.token1Require);
        IBEP20(requirement.token2).transferFrom(_msgSender(), feeAddress, requirement.token2Require);
        bool isSuccess = randomUpgrade(requirement.successPercent);
        if (isSuccess) {
            uint8 newStar = currentStar + 1;
            cnft.upgrade(_heroIds[0], newStar);
            for (uint256 k = 1; k < length; k++) {
                nft.transferFrom(_msgSender(), deadAddress, _heroIds[k]);
            }
            emit StarUpgrade(_heroIds[0], newStar, true);
        } else {
            emit StarUpgrade(_heroIds[0], currentStar, false);
        }
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(uint256 _heroId, uint8 _level, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _level));
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }

    function randomUpgrade(uint8 _successPercent) internal returns (bool) {
        uint random = getRandomNumber();
        uint seed = random % 100;
        if (seed < _successPercent) {
            return true;
        }
        return false;
    }
    
    function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }
    
    function updateNft(address _newAddress) external onlyOwner {
        nft = INFT(_newAddress);
    }
    
    function updateCnft(address _newAddress) external onlyOwner {
        cnft = CNFT(_newAddress);
    }

    function updateFeeAddress(address _newAddress) external onlyOwner {
        feeAddress = _newAddress;
    }

    function getRequirement(uint8 _currentStar) public view returns (Requirement memory) {
        return requirements[_currentStar];
    }

    function setRequirement(uint8 _star, address _token1, uint256 _token1Require, address _token2, uint256 _token2Require, uint8 _numberHeroRequire, uint8 _successPercent) public onlyOwner {
        requirements[_star] = Requirement({
            token1: _token1,
            token1Require: _token1Require,
            token2: _token2,
            token2Require: _token2Require,
            numberHeroRequire: _numberHeroRequire,
            successPercent: _successPercent
        });
    }
}