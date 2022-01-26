// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IHero {
	struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);

	function transferFrom(address from, address to, uint256 tokenId) external;
	
	function upgrade(uint256 _tokenId, uint8 _star) external;
	
	function spawn(address to, bool _isGenesis, uint8 _star) external;
	
	function latestTokenId() external view returns(uint);
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

interface Item {
    function latestItemId() external returns (uint256);

    function mintItem(address _to, uint8 _star, uint256 _itemType) external;

    function getItemTypes(uint8 _star) external returns (uint256[] memory);
}

contract StakeNFT is Ownable, IHero {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    INFT public nft;
    Item public item;

    struct Package {
        uint256 numberHeroRequire;
        uint256 starRequire;
        uint256 stakePeriod;
        uint8 itemStar;
        uint256 itemType;
        uint256 slots;
        uint256 total;
        bool available;
    }

    mapping (uint256 => Package) public packages;

    struct Record {
        address owner;
        uint256[] nftIds;
        uint256 packageId;
        uint256 stakePeriod;
        uint256 startAt;
        bool claimed;
    }

    mapping (uint256 => Record) public records;

    uint256 private _lastRecordId;

    mapping (address => mapping(uint256 => bool)) public stakingPackages;

    mapping (address => EnumerableSet.UintSet) private stakingRecords;

    event Staking(address indexed owner, uint256 packageId, uint256 recordId);

    event Claim(address indexed owner, uint256 packageId, uint256 recordId, uint256 itemId);
    
    constructor(address _nft, address _item) {
        nft = INFT(_nft);
        item = Item(_item);
    }

    function stake(uint256 _packageId, uint256[] memory _nftIds) external {
        require(stakingPackages[msg.sender][_packageId] == false, "package staked");
        Package memory package = packages[_packageId];
        require(package.available, "not available");
        require(package.slots > 0, "out of stake slots");
        uint256 length = _nftIds.length;
        require(length >= package.numberHeroRequire, "not enough hero");
        for (uint256 i = 0; i < length; i++) {
            Hero memory hero = nft.getHero(_nftIds[i]);
            require(nft.ownerOf(_nftIds[i]) == msg.sender, "not owner");
            require(hero.star >= package.starRequire, "star require not match");
            nft.transferFrom(msg.sender, address(this), _nftIds[i]);
        }
        uint256 nextRecordId = _getNextRecordId();
		_incrementRecordId();
        records[nextRecordId] = Record({
            owner: msg.sender,
            nftIds: _nftIds,
            packageId: _packageId,
            stakePeriod: package.stakePeriod,
            startAt: block.timestamp,
            claimed: false
        });
        package.slots.sub(1);
        stakingRecords[msg.sender].add(nextRecordId);
        stakingPackages[msg.sender][_packageId] == true;
        emit Staking(msg.sender, _packageId, nextRecordId);
    }

    function claim(uint256 _recordId) external {
        Record memory record = records[_recordId];
        require(record.claimed == false, "claimed");
        Package memory package = packages[record.packageId];
        require(package.available, "not available");
        require(msg.sender == record.owner, "not owner");
        require(record.startAt + record.stakePeriod <= block.timestamp, "not enough stake time");
        for (uint256 i = 0; i < record.nftIds.length; i++) {
            nft.transferFrom(address(this), msg.sender, record.nftIds[i]);
        }
        item.mintItem(record.owner, package.itemStar, package.itemType);
        uint256 newItemId = item.latestItemId();
        record.claimed = true;
        stakingRecords[msg.sender].remove(_recordId);
        stakingPackages[msg.sender][record.packageId] == false;
        emit Claim(record.owner, record.packageId, _recordId, newItemId);
    }

    function getStakingRecordIds() external view returns (uint256[] memory) {
        uint256 length = stakingRecords[msg.sender].length();
        uint256[] memory recordIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            recordIds[i] = stakingRecords[msg.sender].at(i);
        }
        return recordIds;
    }

    function updatePackage(uint8 _id, uint256 _numberHeroRequire, uint8 _starRequire, uint256 _stakePeriod, uint8 _itemStar, uint256 _itemType, uint256 _slots, uint256 _total, bool _available) external onlyOwner {
        packages[_id] = Package({
            numberHeroRequire: _numberHeroRequire,
            starRequire: _starRequire,
            stakePeriod: _stakePeriod,
            itemStar: _itemStar,
            itemType: _itemType,
            slots: _slots,
            total: _total,
            available: _available
        });
    }

    function getPackage(uint8 _id) public view returns (Package memory) {
        return packages[_id];
    }

    function getRecord(uint256 _recordId) public view returns (Record memory) {
        return records[_recordId];
    }

    function updatNft(address _nft) external onlyOwner {
        nft = INFT(_nft);
    }

    function updateItem(address _item) external onlyOwner {
        item = Item(_item);
    }

    function transferBack(uint256 _nftId) external onlyOwner {
	    nft.transferFrom(address(this), _msgSender(), _nftId);
	}

    function _getNextRecordId() private view returns (uint256) {
        return _lastRecordId.add(1);
    }
    
    function _incrementRecordId() private {
        _lastRecordId++;
    }
    
    function latestRecordId() external view returns(uint) {
        return _lastRecordId;
    }
}