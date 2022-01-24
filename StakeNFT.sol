// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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

    INFT public nft;
    Item public item;

    struct Package {
        uint256 starRequire;
        uint256 stakePeriod;
        uint8 itemStar;
        uint256 itemType;
        uint256 total;
        bool available;
    }

    mapping (uint256 => Package) public packages;

    struct Record {
        address owner;
        uint256 nftId;
        uint256 packageId;
        uint256 stakePeriod;
        uint256 startAt;
    }

    mapping (uint256 => Record) public records;

    uint256 private _lastRecordId;

    event Staking(address indexed owner, uint256 packageId, uint256 recordId);

    event Claim(address indexed owner, uint256 packageId, uint256 recordId, uint256 itemId);
    
    constructor(address _nft, address _item) {
        nft = INFT(_nft);
        item = Item(_item);
    }

    function stake(uint256 _packageId, uint256 _nftId) external {
        Package memory package = packages[_packageId];
        require(package.available, "not available");
        require(package.total > 0, "out of stake slots");
        Hero memory hero = nft.getHero(_nftId);
        require(hero.star >= package.starRequire, "star require not match");
        nft.transferFrom(msg.sender, address(this), _nftId);
        uint256 nextRecordId = _getNextRecordId();
		_incrementRecordId();
        records[nextRecordId] = Record({
            owner: msg.sender,
            nftId: _nftId,
            packageId: _packageId,
            stakePeriod: package.stakePeriod,
            startAt: block.timestamp
        });
        package.total.sub(1);
        emit Staking(msg.sender, _packageId, nextRecordId);
    }

    function claim(uint256 _recordId) external {
        Record memory record = records[_recordId];
        Package memory package = packages[record.packageId];
        require(package.available, "not available");
        require(msg.sender == record.owner, "not owner");
        require(record.startAt + record.stakePeriod <= block.timestamp, "not enough stake time");
        nft.transferFrom(address(this), msg.sender, record.nftId);
        item.mintItem(record.owner, package.itemStar, package.itemType);
        uint256 newItemId = item.latestItemId();
        emit Claim(record.owner, record.packageId, _recordId, newItemId);
    }

    function updatePackage(uint8 _id, uint8 _starRequire, uint256 _stakePeriod, uint8 _itemStar, uint256 _itemType, uint256 _total, bool _available) external onlyOwner {
        packages[_id] = Package({
            starRequire: _starRequire,
            stakePeriod: _stakePeriod,
            itemStar: _itemStar,
            itemType: _itemType,
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