// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IHero {
    struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 plantClass;
        uint256 plantId;
        uint256 bornAt;
    }
}

interface ICNFT {
    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _plantClass, uint256 _plantId) external;

    function getNft() external view returns (address);
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);

	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface INFT is IERC721, IHero {
	function latestTokenId() external view returns(uint);

	function getHero(uint256 _tokenId) external view returns (Hero memory);

	function getTotalClass() external view returns (uint8);

    function getPlanIds(uint8 _plantClass, uint8 _rarity) external view returns (uint256[] memory);
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

contract PlantFusion is Ownable, IHero {
	using SafeMath for uint256;

	ICNFT public cnft;

	IHolyPackage public holyPackage;

	struct Requirement {
		uint8 baseRate;
		uint8 addRate;
		address token;
		uint256 tokenRequire;
		uint8 holyPackageMaxAmount;
	}

	mapping (uint8 => Requirement) public requirements;

	mapping (string => uint8) public plantClasses;

	uint nonce = 0;

	address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    address public feeAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;

	uint8[] classList = [1,2,3,4];

	uint8 classBaseRate;

	uint8 classAddRate;

	event FusionSuccess(uint256[] heroId, uint256 _newHeroId);

	event FusionFail(uint256[] heroId, uint256 _newHeroId);

	constructor(address _cnft, address _holyPackage, uint8 _classBaseRate, uint8 _classAddRate) {
		cnft = ICNFT(_cnft);
		holyPackage = IHolyPackage(_holyPackage);
		classBaseRate = _classBaseRate;
		classAddRate = _classAddRate;
	}

	function fusion(uint256[] memory _heroIds, uint256[] memory _holyPackageIds) external {
		INFT nft = INFT(cnft.getNft());
		uint8 requiredRarity = nft.getHero(_heroIds[0]).rarity;
		require(requiredRarity > 2 && requiredRarity < 5, "require: invalid rariry");
		for (uint256 k = 0; k < _heroIds.length; k++) {
            require(nft.ownerOf(_heroIds[k]) == _msgSender(), "require: must be owner of plants");
			require(nft.getHero(_heroIds[k]).rarity == requiredRarity, "require: must same rariry");
		}
        Requirement memory requirement = requirements[requiredRarity];
		require(requirement.token != address(0), "invalid token");
		uint256 length = _holyPackageIds.length;
		require(length <= requirement.holyPackageMaxAmount, "exceed max holy package amount");
		string memory requiredHolyType = holyPackage.getPackage(_holyPackageIds[0]).holyType;
		for (uint256 i = 0; i < length; i++) {
            require(holyPackage.ownerOf(_holyPackageIds[i]) == _msgSender(), "require: must be owner of holies");
			require(compareStrings(holyPackage.getPackage(_holyPackageIds[i]).holyType, requiredHolyType), "require: wrong holy type");
        }
		uint8 successRate = getSuccessRate(requirement.baseRate, requirement.addRate, length);
		require(successRate <= 100, "invalid");
		IBEP20(requirement.token).transferFrom(_msgSender(), feeAddress, getFee(requiredRarity));
		for (uint256 k = 0; k < _heroIds.length; k++) {
			nft.transferFrom(_msgSender(), deadAddress, _heroIds[k]);
		}
        for (uint256 i = 0; i < length; i++) {
            holyPackage.transferFrom(_msgSender(), deadAddress, _holyPackageIds[i]);
        }
		uint256 randomNumber = getRandomNumber();
		bool isSuccess = randomFusion(randomNumber, successRate);
		uint8 classSuccessRate = getSuccessRate(classBaseRate, classAddRate, length);
		uint8 plantClass = randomClass(randomNumber, classSuccessRate, plantClasses[requiredHolyType]);
		uint8 rarity = requiredRarity;
		if (isSuccess) {
			rarity = requiredRarity + 1;
		}
		uint256 planId = getPlantId(plantClass, rarity, randomNumber);
		cnft.mint(_msgSender(), 3, rarity, plantClass, planId);
		uint256 newHeroId = nft.latestTokenId();
		if (isSuccess) {
			emit FusionSuccess(_heroIds, newHeroId);
		} else {
			emit FusionFail(_heroIds, newHeroId);
		}
	}

	function getPlantId(uint8 _planClass, uint8 _rarity, uint256 _randomNumber) internal returns (uint256) {
        INFT nft = INFT(cnft.getNft());
        uint256[] memory planIds = nft.getPlanIds(_planClass, _rarity);
        return planIds[_randomNumber.mod(planIds.length)];
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
		uint seed = _randomNumber % 100;
		if (seed < _successRate) {
			return _targetClass;
		}
        uint256 totalClass = classList.length;
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

	function setPlanClasses(string memory _holyType, uint8 _planClass) external onlyOwner {
		plantClasses[_holyType] = _planClass;
	}

	function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}