// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

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
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

contract HeroFarm is Ownable, IHero {
    using SafeMath for uint256;

    INFT public nft;

    struct Record {
        uint256[] heroIds;
        uint256 totalStar;
        uint256 rewardDebt;
    }

    struct Pool {
        IBEP20 rewardToken;
        uint8 starRequire;
        uint256 totalStar;
        uint256 rewardPerBlock;
        uint256 endBlock;
        uint256 lastRewardBlock;
        uint256 accRofiPerShare;
        bool available;
    }

    mapping (uint256 => Pool) public pools;
    mapping (uint256 => mapping(address => Record)) public records;

    event Deposit(address indexed user, uint256 poolId, uint256 heroId);
    event Withdraw(address indexed user, uint256 poolId, uint256 heroId);
    event CollectReward(address indexed user, uint256 poolId, uint256 amount);

    constructor(address _nft) {
        nft = INFT(_nft);
    }

    function updatePool(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 totalStar = pool.totalStar;
        if (totalStar == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 rofiReward = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock).mul(pool.rewardPerBlock);
        pool.accRofiPerShare = pool.accRofiPerShare.add(rofiReward.mul(1e12).div(totalStar));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _poolId, uint256 _heroId) public {
        Pool storage pool = pools[_poolId];
        require(pool.available, "pool not available");
        Record storage record = records[_poolId][msg.sender];
        updatePool(_poolId);
        if (record.totalStar > 0) {
            uint256 pending = record.totalStar.mul(pool.accRofiPerShare).div(1e12).sub(record.rewardDebt);
            if (pending > 0) {
                pool.rewardToken.transfer(address(msg.sender), pending);
            }
        }
        require(nft.ownerOf(_heroId) == msg.sender, "not owner");
        Hero memory hero = nft.getHero(_heroId);
        require(hero.star >= pool.starRequire, "not enough star");
        nft.transferFrom(msg.sender, address(this), _heroId);
        record.totalStar = record.totalStar.add(hero.star);
        record.heroIds.push(_heroId);
        record.rewardDebt = record.totalStar.mul(pool.accRofiPerShare).div(1e12);
        pool.totalStar = pool.totalStar.add(hero.star);
        emit Deposit(msg.sender, _poolId, _heroId);
    }

    function bulkDeposit(uint256 _poolId, uint256[] memory _heroIds) public {
        for(uint256 i = 0; i < _heroIds.length; i++) {
            deposit(_poolId, _heroIds[0]);
        }
    }

    function withdraw(uint256 _poolId, uint256 _heroId) public {
        Pool storage pool = pools[_poolId];
        require(pool.available, "pool not available");
        Record storage record = records[_poolId][msg.sender];
        bool found = false;
        uint256 index = 0;
        for (uint256 i = 0; i < record.heroIds.length; i++) {
            if (record.heroIds[i] == _heroId) {
                found = true;
                index = i;
            }
        }
        require(found == true, "not found hero");
        require(index >= 0, "not found index");
        updatePool(_poolId);
        uint256 pending = record.totalStar.mul(pool.accRofiPerShare).div(1e12).sub(record.rewardDebt);
        if (pending > 0) {
            pool.rewardToken.transfer(address(msg.sender), pending);
        }
        Hero memory hero = nft.getHero(_heroId);
        nft.transferFrom(address(this), msg.sender, _heroId);
        record.totalStar = record.totalStar.sub(hero.star);
        delete record.heroIds[index];
        record.rewardDebt = record.totalStar.mul(pool.accRofiPerShare).div(1e12);
        pool.totalStar = pool.totalStar.sub(hero.star);
        emit Withdraw(msg.sender, _poolId, _heroId);
    }

    function bulkWithdraw(uint256 _poolId, uint256[] memory _heroIds) public {
        for(uint256 i = 0; i < _heroIds.length; i++) {
            withdraw(_poolId, _heroIds[0]);
        }
    }

    function pendingRofi(uint256 _poolId, address _user) external view returns (uint256) {
        Pool storage pool = pools[_poolId];
        Record storage record = records[_poolId][_user];
        uint256 accRofiPerShare = pool.accRofiPerShare;
        uint256 totalStar = pool.totalStar;
        if (block.number > pool.lastRewardBlock && totalStar != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
            uint256 rofiReward = multiplier.mul(pool.rewardPerBlock);
            accRofiPerShare = accRofiPerShare.add(rofiReward.mul(1e12).div(totalStar));
        }
        return record.totalStar.mul(accRofiPerShare).div(1e12).sub(record.rewardDebt);
    }

    function collectReward(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        Record storage record = records[_poolId][msg.sender];
        updatePool(_poolId);
        uint256 pending = record.totalStar.mul(pool.accRofiPerShare).div(1e12).sub(record.rewardDebt);
        if (pending > 0) {
            pool.rewardToken.transfer(address(msg.sender), pending);
        }
        record.rewardDebt = record.totalStar.mul(pool.accRofiPerShare).div(1e12);
        emit CollectReward(msg.sender, _poolId, pending);
    }

    function getMultiplier(uint256 _from, uint256 _to, uint256 _endBlock) internal view returns (uint256) {
        if (_to <= _endBlock) {
            return _to - _from;
        } else if (_from >= _endBlock) {
            return 0;
        } else {
            return _endBlock - _from;
        }
    }

    function updatNft(address _nft) external onlyOwner {
        nft = INFT(_nft);
    }

    function setPool(
        uint256 _poolId,
        address _rewardToken,
        uint8 _starRequire,
        uint256 _totalStar,
        uint256 _rewardPerBlock,
        uint256 _endBlock,
        uint256 _lastRewardBlock,
        uint256 _accRofiPerShare
    ) public onlyOwner {
        pools[_poolId] = Pool({
            rewardToken: IBEP20(_rewardToken),
            starRequire: _starRequire,
            totalStar: _totalStar,
            rewardPerBlock: _rewardPerBlock,
            endBlock: _endBlock,
            lastRewardBlock: _lastRewardBlock,
            accRofiPerShare: _accRofiPerShare,
            available: true
        });
    }

    function closePool(uint256 _poolId) public onlyOwner {
        Pool storage pool = pools[_poolId];
        pool.available = false;
        pool.rewardToken.transfer(msg.sender, pool.rewardToken.balanceOf(address(this)));
    }

    function withdrawHero(uint256[] memory _heroIds) public onlyOwner {
        for (uint256 i = 0; i < _heroIds.length; i++) {
            nft.transferFrom(address(this), msg.sender, _heroIds[i]);
        }
    }
}