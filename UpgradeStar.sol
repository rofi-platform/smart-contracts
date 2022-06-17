//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IHero {
    struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 plantClass;
        uint256 plantId;
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

contract UpgradeStar is Ownable, IHero {
    CNFT public cnft;
    
    INFT public nft;

    IERC721 public holyPackage;
                
    mapping (uint8 => uint256) upgradeStarFee;

    struct Requirement {
        address token;
        uint256 tokenRequire;
        uint8 levelRequire;
        uint8 holyPackageRequire;
        uint8[] successPercents;
    }

    mapping (uint8 => Requirement) requirements;

    event StarUpgrade(uint256 heroId, uint8 newStar, bool isSuccess);
        
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

    uint nonce = 0;

    bytes32 public merkleRoot;

    mapping (uint256 => uint8) records;

    constructor(address _nft, address _cnft, address _holyPackage, address _feeAddress) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
        holyPackage = IERC721(_holyPackage);
        feeAddress = _feeAddress;
    }

    function upgradeStar(uint256 _heroId, uint256[] memory _holyPackageIds, uint8 _level, bytes32[] memory _proof) external {
        require(nft.ownerOf(_heroId) == _msgSender(), "require: must be owner");
        Hero memory hero = nft.getHero(_heroId);
        uint8 currentStar = hero.star;
        Requirement memory requirement = requirements[currentStar];
        require(_level >= requirement.levelRequire, "require: level not enough");
        require(MerkleProof.verify(_proof, merkleRoot, bytes32(keccak256(abi.encodePacked(_heroId, _level)))), "data is outdated or invalid");
        uint256 length = _holyPackageIds.length;
        require(length == requirement.holyPackageRequire, "require: number of holy packages not correct");
        bool isOwner = true;
        for (uint256 i = 0; i < length; i++) {
            if (holyPackage.ownerOf(_holyPackageIds[i]) != _msgSender()) {
                isOwner = false;
            }
        }
        require(isOwner, "require: must be owner of holies");
        IBEP20(requirement.token).transferFrom(_msgSender(), feeAddress, requirement.tokenRequire);
        uint8 upgradeTimes = records[_heroId] + 1;
        bool isSuccess = false;
        if (upgradeTimes == requirement.successPercents.length) {
            isSuccess = true;
        } else {
            isSuccess = randomUpgrade(requirement.successPercents[upgradeTimes - 1]);
        }
        if (isSuccess) {
            uint8 newStar = currentStar + 1;
            cnft.upgrade(_heroId, newStar);
            for (uint256 k = 1; k < length; k++) {
                holyPackage.transferFrom(_msgSender(), deadAddress, _holyPackageIds[k]);
            }
            emit StarUpgrade(_heroId, newStar, true);
        } else {
            emit StarUpgrade(_heroId, currentStar, false);
        }
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

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
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

    function updateFeeAddress(address _newAddress) external onlyOwner {
        feeAddress = _newAddress;
    }

    function getRequirement(uint8 _currentStar) public view returns (Requirement memory) {
        return requirements[_currentStar];
    }

    function setRequirement(uint8 _star, address _token, uint256 _tokenRequire, uint8 _levelRequire, uint8 _holyPackageRequire, uint8[] memory _successPercents) public onlyOwner {
        requirements[_star] = Requirement({
            token: _token,
            tokenRequire: _tokenRequire,
            levelRequire: _levelRequire,
            holyPackageRequire: _holyPackageRequire,
            successPercents: _successPercents
        });
    }
}