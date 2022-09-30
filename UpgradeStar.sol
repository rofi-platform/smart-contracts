//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface CNFT {
    function upgrade(uint256 _tokenId, uint8 _star) external;
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
	
	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IHolyPackage is IERC721 {
    struct Package {
        string holyType;
        uint256 createdAt;
    }

    function getPackage(uint256 _packageId) external returns (Package memory);
}

interface IHero {
    struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 plantClass;
        uint256 plantId;
        uint256 bornAt;
    }
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

interface IBEP20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract UpgradeStar is IHero, Ownable, Pausable {
    using ECDSA for bytes32;

    CNFT public cnft;
    
    INFT public nft;

    IHolyPackage public holyPackage;
                
    mapping (uint8 => uint256) upgradeStarFee;

    struct Requirement {
        address token;
        uint256[] tokenRequire;
        uint8 levelRequire;
        uint8 holyPackageRequire;
        uint8[] successPercents;
    }

    mapping (uint8 => Requirement) requirements;

    mapping (uint8 => string) requireHolyColor;

    event StarUpgrade(uint256 heroId, uint8 newStar, bool isSuccess);
        
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

    uint nonce = 0;

    bytes32 public merkleRoot;

    mapping (uint256 => uint8) records;

    uint256 public requestExpire = 300;

    address public validator;

    constructor(address _nft, address _cnft, address _holyPackage, address _feeAddress) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
        holyPackage = IHolyPackage(_holyPackage);
        feeAddress = _feeAddress;
        validator = owner();
    }

    function upgradeStar(uint256 _heroId, uint256[] memory _holyPackageIds, uint8 _level, uint256 _nonce, bytes memory _sign) external whenNotPaused {
        require(nft.ownerOf(_heroId) == _msgSender(), "require: must be owner");
        Hero memory hero = nft.getHero(_heroId);
        Requirement memory requirement = requirements[hero.star];
        require(_level >= requirement.levelRequire, "require: level not enough");
        require(block.timestamp <= _nonce + requestExpire, "Request expired");
        require(validateSign(_heroId, _level, _nonce, _sign), "Invalid sign");
        uint256 length = _holyPackageIds.length;
        require(length == requirement.holyPackageRequire, "require: number of holy packages not correct");
        string memory requiredHolyType = getRequiredHolyType(hero.plantClass);
        for (uint256 i = 0; i < length; i++) {
            require(holyPackage.ownerOf(_holyPackageIds[i]) == _msgSender(), "require: must be owner of holies");
            require(compareStrings(holyPackage.getPackage(_holyPackageIds[i]).holyType, requiredHolyType), "require: wrong holy type");
        }
        IBEP20(requirement.token).transferFrom(_msgSender(), feeAddress, getFee(hero.star, hero.rarity));
        for (uint256 k = 0; k < length; k++) {
            holyPackage.transferFrom(_msgSender(), deadAddress, _holyPackageIds[k]);
        }
        uint8 upgradeTimes = records[_heroId] + 1;
        bool isSuccess = false;
        if (upgradeTimes == requirement.successPercents.length) {
            isSuccess = true;
        } else {
            isSuccess = randomUpgrade(requirement.successPercents[upgradeTimes - 1]);
        }
        if (isSuccess) {
            records[_heroId] = 0;
            uint8 newStar = hero.star + 1;
            cnft.upgrade(_heroId, newStar);
            emit StarUpgrade(_heroId, newStar, true);
        } else {
            records[_heroId] = upgradeTimes;
            emit StarUpgrade(_heroId, hero.star, false);
        }
    }

    function validateSign(uint256 _heroId, uint8 _level, uint256 _nonce, bytes memory _sign) public view returns (bool) {
        bytes32 _hash = keccak256(abi.encodePacked(_heroId, _level, _nonce));
        address _signer = _hash.toEthSignedMessageHash().recover(_sign);
        return _signer == validator;
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

    function getNextSuccessPercent(uint256 _heroId) public view returns (uint8) {
        Hero memory hero = nft.getHero(_heroId);
        Requirement memory requirement = requirements[hero.star];
        return requirement.successPercents[records[_heroId]];
    }

    function getRequiredHolyType(uint8 _plantClass) public view returns (string memory) {
        if (_plantClass == 1) {
            return "blue";
        } else if (_plantClass == 2) {
            return "red";
        } else if (_plantClass == 3) {
            return "yellow";
        } else {
            return "green";
        }
    }

    function setRequirement(uint8 _star, address _token, uint256[] memory _tokenRequire, uint8 _levelRequire, uint8 _holyPackageRequire, uint8[] memory _successPercents) public onlyOwner {
        requirements[_star] = Requirement({
            token: _token,
            tokenRequire: _tokenRequire,
            levelRequire: _levelRequire,
            holyPackageRequire: _holyPackageRequire,
            successPercents: _successPercents
        });
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function setExpireTime(uint256 _number) external onlyOwner {
        requestExpire = _number;
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function updateHolyPackage(address _holyPackage) external onlyOwner {
        holyPackage = IHolyPackage(_holyPackage);
    }

    function getFee(uint8 _star, uint8 _rarity) public view returns (uint256) {
        Requirement memory requirement = requirements[_star];
        return requirement.tokenRequire[_rarity + 1];
    }
}