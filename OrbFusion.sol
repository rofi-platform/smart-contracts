// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IOrb {
    struct Orb {
        uint8 star;
        uint8 rarity;
        uint8 classType;
        uint256 bornAt;
    }
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);

	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IOrbNFT is IERC721, IOrb {
	function getOrb(uint256 _tokenId) external view returns (Orb memory);

    function mintOrb(address to, uint8 _star, uint8 _rarity, uint8 _classType) external;

    function latestOrbId() external view returns (uint256);
}

interface IHolyPackage is IERC721 {
    struct Package {
        string holyType;
        uint256 createdAt;
    }

    function getPackage(uint256 _packageId) external returns (Package memory);
}

interface IBEP20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract OrbFusion is Ownable, IOrb {
	using SafeMath for uint256;

    IOrbNFT public orbNft;

	IHolyPackage public holyPackage;

	struct Requirement {
		uint8 baseRate;
		uint8 addRate;
		address token;
		uint256 tokenRequire;
		uint8 holyPackageMaxAmount;
	}

	mapping (uint8 => Requirement) public requirements;

	mapping (string => uint8) public orbClasses;

	uint nonce = 0;

	address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

	uint8[] classList = [1,2,3];

	uint8 classBaseRate;

	uint8 classAddRate;

	event Fusion(bool isSuccess, uint256[] orbIds, uint256 newOrbId);

	constructor(address _orbNft, address _holyPackage, uint8 _classBaseRate, uint8 _classAddRate) {
        orbNft = IOrbNFT(_orbNft);
		holyPackage = IHolyPackage(_holyPackage);
		classBaseRate = _classBaseRate;
		classAddRate = _classAddRate;
	}

	function fusion(uint256[] memory _orbIds, uint256[] memory _holyPackageIds) external {
		uint8 requiredRarity = orbNft.getOrb(_orbIds[0]).rarity;
		require(requiredRarity > 2 && requiredRarity < 5, "require: invalid rariry");
		for (uint256 k = 0; k < _orbIds.length; k++) {
            require(orbNft.ownerOf(_orbIds[k]) == _msgSender(), "require: must be owner of orb");
			require(orbNft.getOrb(_orbIds[k]).rarity == requiredRarity, "require: must same rariry");
		}
        Requirement memory requirement = requirements[requiredRarity];
		require(requirement.token != address(0), "invalid token");
		uint256 length = _holyPackageIds.length;
		uint8 targetClass = 0;
		if (length > 0) {
			require(length <= requirement.holyPackageMaxAmount, "exceed max holy package amount");
			string memory requiredHolyType = holyPackage.getPackage(_holyPackageIds[0]).holyType;
			for (uint256 i = 0; i < length; i++) {
				require(holyPackage.ownerOf(_holyPackageIds[i]) == _msgSender(), "require: must be owner of holies");
				require(compareStrings(holyPackage.getPackage(_holyPackageIds[i]).holyType, requiredHolyType), "require: wrong holy type");
			}
			for (uint256 i = 0; i < length; i++) {
				holyPackage.transferFrom(_msgSender(), deadAddress, _holyPackageIds[i]);
			}
			targetClass = orbClasses[requiredHolyType];
		}
		uint8 successRate = getSuccessRate(requirement.baseRate, requirement.addRate, length);
		require(successRate <= 100, "invalid");
		IBEP20(requirement.token).transferFrom(_msgSender(), feeAddress, getFee(requiredRarity));
		for (uint256 k = 0; k < _orbIds.length; k++) {
			orbNft.transferFrom(_msgSender(), deadAddress, _orbIds[k]);
		}
		uint256 randomNumber = getRandomNumber();
		bool isSuccess = randomFusion(randomNumber, successRate);
		uint8 classSuccessRate = getSuccessRate(classBaseRate, classAddRate, length);
		uint8 orbClass = randomClass(randomNumber, classSuccessRate, targetClass);
		uint8 rarity = requiredRarity;
		if (isSuccess) {
			rarity = requiredRarity + 1;
		}
		orbNft.mintOrb(_msgSender(), 3, rarity, orbClass);
		emit Fusion(isSuccess, _orbIds, orbNft.latestOrbId());
	}

	function getFee(uint8 _rarity) public view returns (uint256) {
		Requirement memory requirement = requirements[_rarity];
		return requirement.tokenRequire;
	}

	function getSuccessRate(uint8 _baseRate, uint8 _addRate, uint256 _numberHolyPackage) public view returns (uint8) {
		return uint8(uint256(_baseRate).add(uint256(_addRate).mul(_numberHolyPackage)));
	}

	function randomFusion(uint256 _randomNumber, uint8 _successRate) internal returns (bool) {
        uint seed = _randomNumber % 100;
        if (seed < _successRate) {
            return true;
        }
        return false;
    }

	function randomClass(uint256 _randomNumber, uint8 _successRate, uint8 _targetClass) internal returns (uint8) {
		uint256 totalClass = classList.length;
		uint seed = _randomNumber % 100;
		if (_targetClass == 0) {
			return uint8(_randomNumber.mod(totalClass).add(1));
		}
		if (seed < _successRate) {
			return _targetClass;
		}
		uint8[] memory classes = new uint8[](totalClass.sub(1));
        uint256 count;
		for (uint256 i = 0; i < totalClass; i++) {
			if (classList[i] != _targetClass) {
				classes[count] = classList[i];
                count++;
			}
        }
		return classes[_randomNumber.mod(totalClass.sub(1))];
	}

	function getRandomNumber() internal returns (uint) {
        nonce += 1;
        return uint(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

	function setRequirement(uint8 _rarity, uint8 _baseRate, uint8 _addRate, address _token, uint256 _tokenRequire, uint8 _holyPackageMaxAmount) external onlyOwner {
        requirements[_rarity] = Requirement({
			baseRate: _baseRate,
			addRate: _addRate,
            token: _token,
            tokenRequire: _tokenRequire,
			holyPackageMaxAmount: _holyPackageMaxAmount
        });
    }

	function setOrbClasses(string memory _holyType, uint8 _orbClass) external onlyOwner {
		orbClasses[_holyType] = _orbClass;
	}

	function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}