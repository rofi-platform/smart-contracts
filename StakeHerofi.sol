// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
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

contract StakeHerofi is Ownable, IHero {
	using Counters for Counters.Counter;
	using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

	Counters.Counter public currentRecordId;

	IERC721 public herofiNft;

	uint256 public stakePeriod = 180 days;

    bool public available = true;

	mapping(uint256 => Record) public records;

	mapping (address => EnumerableSet.UintSet) private stakingRecords;

	struct Record {
		address owner;
		uint256[] nftIds;
		uint256 startAt;
		bool unstaked;
	}

	event Stake(address indexed owner, uint256[] nftIds, uint256 startAt, uint256 recordId);

	event Unstake(address indexed owner, uint256[] nftIds, uint256 recordId);

	constructor(address _herofiNft) {
		herofiNft = IERC721(_herofiNft);
	}

	function stake(uint256[] memory _nftIds) external {
        require(available, "not available");
		uint256 length = _nftIds.length;
		for (uint256 i = 0; i < length; i++) {
            require(herofiNft.ownerOf(_nftIds[i]) == msg.sender, "not owner");
            herofiNft.transferFrom(msg.sender, address(this), _nftIds[i]);
        }
		currentRecordId.increment();
        uint256 recordId = currentRecordId.current();
        records[recordId] = Record({
            owner: msg.sender,
			nftIds: _nftIds,
			startAt: block.timestamp,
			unstaked: false
        });
		stakingRecords[msg.sender].add(recordId);
		emit Stake(msg.sender, _nftIds, block.timestamp, recordId);
	}

	function unstake(uint256 _recordId) external {
		Record storage record = records[_recordId];
        require(record.unstaked == false, "unstaked");
		require(msg.sender == record.owner, "not owner");
		require(record.startAt.add(stakePeriod) <= block.timestamp, "not enough stake time");
		for (uint256 i = 0; i < record.nftIds.length; i++) {
            herofiNft.transferFrom(address(this), msg.sender, record.nftIds[i]);
        }
		record.unstaked = true;
		stakingRecords[msg.sender].remove(_recordId);
		emit Unstake(record.owner, record.nftIds, _recordId);
	}

	function getStakingRecordIds() external view returns (uint256[] memory) {
        uint256 length = stakingRecords[msg.sender].length();
        uint256[] memory recordIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            recordIds[i] = stakingRecords[msg.sender].at(i);
        }
        return recordIds;
    }

	function withdraw(uint256[] memory _nftIds) external onlyOwner {
		for (uint256 i = 0; i < _nftIds.length; i++) {
            herofiNft.transferFrom(address(this), msg.sender, _nftIds[i]);
        }
	}

	function updateStakePeriod(uint256 _stakePeriod) external onlyOwner {
		stakePeriod = _stakePeriod;
	}

    function updateAvailable(bool _available) external onlyOwner {
		available = _available;
	}
}