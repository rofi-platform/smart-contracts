//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

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

interface IOrb {
    struct Orb {
        uint8 star;
        uint8 rarity;
        uint8 classType;
        uint256 bornAt;
    }
}

interface IOrbNFT is IERC721, IOrb {
	function getOrb(uint256 _tokenId) external view returns (Orb memory);

    function updateStar(uint256 _orbId, uint8 _newStar) external;
}

interface IBEP20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract UpgradeStarOrb is IOrb, Ownable, Pausable {
    IOrbNFT public orbNft;

    IHolyPackage public holyPackage;

    struct Requirement {
        address token;
        uint256 tokenRequire;
        uint8 holyPackageRequire;
        uint8[] successPercents;
    }

    mapping (uint8 => Requirement) requirements;

    event StarUpgrade(uint256 orbId, uint8 newStar, bool isSuccess);
        
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

    uint nonce = 0;

    mapping (uint256 => uint8) records;

    constructor(address _orbNft, address _holyPackage, address _feeAddress) {
        orbNft = IOrbNFT(_orbNft);
        holyPackage = IHolyPackage(_holyPackage);
        feeAddress = _feeAddress;
    }

    function upgradeStar(uint256 _orbId, uint256[] memory _holyPackageIds) external whenNotPaused {
        require(orbNft.ownerOf(_orbId) == _msgSender(), "require: must be owner");
        Orb memory orb = orbNft.getOrb(_orbId);
        Requirement memory requirement = requirements[orb.star];
        uint256 length = _holyPackageIds.length;
        require(length == requirement.holyPackageRequire, "require: number of holy packages not correct");
        string memory requiredHolyType = getRequiredHolyType(orb.classType);
        for (uint256 i = 0; i < length; i++) {
            require(holyPackage.ownerOf(_holyPackageIds[i]) == _msgSender(), "require: must be owner of holies");
            require(compareStrings(holyPackage.getPackage(_holyPackageIds[i]).holyType, requiredHolyType), "require: wrong holy type");
        }
        IBEP20(requirement.token).transferFrom(_msgSender(), feeAddress, requirement.tokenRequire);
        uint8 upgradeTimes = records[_orbId] + 1;
        bool isSuccess = false;
        if (upgradeTimes == requirement.successPercents.length) {
            isSuccess = true;
        } else {
            isSuccess = randomUpgrade(requirement.successPercents[upgradeTimes - 1]);
        }
        if (isSuccess) {
            records[_orbId] = 0;
            uint8 newStar = orb.star + 1;
            orbNft.updateStar(_orbId, newStar);
            for (uint256 k = 0; k < length; k++) {
                holyPackage.transferFrom(_msgSender(), deadAddress, _holyPackageIds[k]);
            }
            emit StarUpgrade(_orbId, newStar, true);
        } else {
            records[_orbId] = upgradeTimes;
            emit StarUpgrade(_orbId, orb.star, false);
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

    function updateOrbNft(address _newAddress) external onlyOwner {
        orbNft = IOrbNFT(_newAddress);
    }

    function updateFeeAddress(address _newAddress) external onlyOwner {
        feeAddress = _newAddress;
    }

    function getRequirement(uint8 _currentStar) public view returns (Requirement memory) {
        return requirements[_currentStar];
    }

    function getNextSuccessPercent(uint256 _orbId) public view returns (uint8) {
        Orb memory orb = orbNft.getOrb(_orbId);
        Requirement memory requirement = requirements[orb.star];
        return requirement.successPercents[records[_orbId]];
    }

    function getRequiredHolyType(uint8 _classType) public view returns (string memory) {
        if (_classType == 1) {
            return "green";
        } else if (_classType == 2) {
            return "red";
        } else if (_classType == 3) {
            return "yellow";
        } else {
            return "blue";
        }
    }

    function setRequirement(uint8 _star, address _token, uint256 _tokenRequire, uint8 _holyPackageRequire, uint8[] memory _successPercents) public onlyOwner {
        requirements[_star] = Requirement({
            token: _token,
            tokenRequire: _tokenRequire,
            holyPackageRequire: _holyPackageRequire,
            successPercents: _successPercents
        });
    }

    function updateHolyPackage(address _holyPackage) external onlyOwner {
        holyPackage = IHolyPackage(_holyPackage);
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}