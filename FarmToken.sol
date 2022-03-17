// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IBEP20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract FarmToken is Ownable {
    using SafeMath for uint256;

    struct Record {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct Pool {
        IBEP20 lpToken;
        IBEP20 rewardToken;
        uint256 rewardPerBlock;
        uint256 endBlock;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        bool available;
    }

    mapping (uint256 => Pool) pools;
    mapping (uint256 => mapping(address => Record)) records;

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount);
    event CollectReward(address indexed user, uint256 indexed poolId, uint256 amount);

    constructor() {

    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 totalReward = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock).mul(pool.rewardPerBlock);
        pool.accRewardPerShare = pool.accRewardPerShare.add(totalReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _poolId, uint256 _amount) public {
        Pool storage pool = pools[_poolId];
        require(pool.available, "pool not available");
        Record storage record = records[_poolId][msg.sender];
        updatePool(_poolId);
        if (record.amount > 0) {
            uint256 pending = record.amount.mul(pool.accRewardPerShare).div(1e12).sub(record.rewardDebt);
            if (pending > 0) {
                pool.rewardToken.transfer(address(msg.sender), pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(address(msg.sender), address(this), _amount);
            record.amount = record.amount.add(_amount);
        }
        record.rewardDebt = record.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _poolId, _amount);
    }

    function withdraw(uint256 _poolId, uint256 _amount) public {
        Pool storage pool = pools[_poolId];
        require(pool.available, "pool not available");
        Record storage record = records[_poolId][msg.sender];
        require(record.amount >= _amount, "withdraw: not good");
        updatePool(_poolId);
        uint256 pending = record.amount.mul(pool.accRewardPerShare).div(1e12).sub(record.rewardDebt);
        if(pending > 0) {
            pool.rewardToken.transfer(address(msg.sender), pending);
        }
        if(_amount > 0) {
            record.amount = record.amount.sub(_amount);
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        record.rewardDebt = record.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _poolId, _amount);
    }

    function claimableReward(uint256 _poolId, address _user) external view returns (uint256) {
        Pool storage pool = pools[_poolId];
        Record storage record = records[_poolId][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
            uint256 totalReward = multiplier.mul(pool.rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(totalReward.mul(1e12).div(lpSupply));
        }
        return record.amount.mul(accRewardPerShare).div(1e12).sub(record.rewardDebt);
    }

    function claimReward(uint256 _poolId) public {
        Pool storage pool = pools[_poolId];
        Record storage record = records[_poolId][msg.sender];
        updatePool(_poolId);
        uint256 pending = record.amount.mul(pool.accRewardPerShare).div(1e12).sub(record.rewardDebt);
        if (pending > 0) {
            pool.rewardToken.transfer(address(msg.sender), pending);
        }
        record.rewardDebt = record.amount.mul(pool.accRewardPerShare).div(1e12);
        emit CollectReward(msg.sender, _poolId, pending);
    }

    function getMultiplier(uint256 _from, uint256 _to, uint256 _endBlock) internal pure returns (uint256) {
        if (_to <= _endBlock) {
            return _to - _from;
        } else if (_from >= _endBlock) {
            return 0;
        } else {
            return _endBlock - _from;
        }
    }

    function setPool(
        uint256 _poolId,
        address _lpToken,
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _endBlock,
        uint256 _lastRewardBlock,
        uint256 _accRewardPerShare
    ) public onlyOwner {
        pools[_poolId] = Pool({
            lpToken: IBEP20(_lpToken),
            rewardToken: IBEP20(_rewardToken),
            rewardPerBlock: _rewardPerBlock,
            endBlock: _endBlock,
            lastRewardBlock: _lastRewardBlock,
            accRewardPerShare: _accRewardPerShare,
            available: false
        });
    }

    function openPool(uint256 _poolId, uint256 _totalReward) external onlyOwner {
        Pool storage pool = pools[_poolId];
        pool.endBlock = block.number.add(_totalReward.div(pool.rewardPerBlock)).add(1);
        pool.available = true;
    }

    function closePool(uint256 _poolId) public onlyOwner {
        Pool storage pool = pools[_poolId];
        pool.available = false;
        pool.rewardToken.transfer(msg.sender, pool.rewardToken.balanceOf(address(this)));
    }

    function emergencyWithdraw(uint256 _poolId) public onlyOwner {
        Pool storage pool = pools[_poolId];
        pool.lpToken.transfer(address(msg.sender), pool.lpToken.balanceOf(address(this)));
    }

    function getPool(uint256 _poolId) public view returns (Pool memory) {
        return pools[_poolId];
    }

    function getRecord(uint256 _poolId, address _user) public view returns (Record memory) {
        return records[_poolId][_user];
    }
}