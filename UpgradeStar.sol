//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

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

interface IROFI {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract UpgradeStar is IHero, Ownable {
    CNFT public cnft;
    
    INFT public nft;
    
    IROFI public rofi;
    
    address public payRofiUnlocked;
                
    mapping (uint8 => uint256) upgradeStarFee;

    mapping (uint8 => uint8) requirements;
    
    event StarUpgrade(uint256 heroId, uint8 newStar);
        
    address public deadAddress = 0x81F403fE697CfcF2c21C019bD546C6b36370458c;
    
    constructor(address _nft, address _cnft, address _rofi, address _payRofiUnlocked) {
        nft = INFT(_nft);
        cnft = CNFT(_cnft);
        rofi = IROFI(_rofi);
        payRofiUnlocked = _payRofiUnlocked;
    }

    function upgradeStar(uint256[] memory _heroIds) external {
        uint256 length = _heroIds.length;
        require(length > 1, "require: at least 2 heroes");
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
        uint8 requirement = requirements[currentStar];
        require(length == requirement, "require: number of heroes not correct");
        uint256 fee = upgradeStarFee[currentStar];
        rofi.transferFrom(_msgSender(), payRofiUnlocked, fee);
        uint8 newStar = currentStar + 1;
        cnft.upgrade(_heroIds[0], newStar);
        for (uint256 k = 1; k < length; k++) {
            nft.transferFrom(_msgSender(), deadAddress, _heroIds[k]);
        }
        emit StarUpgrade(_heroIds[0], newStar);
    }
    
    function updateNft(address _newAddress) external onlyOwner {
        nft = INFT(_newAddress);
    }
    
    function updateCnft(address _newAddress) external onlyOwner {
        cnft = CNFT(_newAddress);
    }
    
    function updatePayRofiUnlocked(address _newAddress) external onlyOwner {
        payRofiUnlocked = _newAddress;
    }
    
    function updateRofi(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
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

    function updateRequirements(uint8[] memory _stars, uint8[] memory _requirements) external onlyOwner {
        uint256 length = _stars.length;
        require(length == _requirements.length, "params not correct");
        for (uint256 i = 0; i < length; i++) {
            uint8 _star = uint8(_stars[i]);
            requirements[_star] = uint8(_requirements[i]);
        }
    }

    function getRequirement(uint8 _currentStar) public view returns (uint8) {
        return requirements[_currentStar];
    }
}