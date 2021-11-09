//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IROFI {
    function mintUnlockedToken(address to, uint256 amount) external;
    
    function mintLockedToken(address to, uint256 amount) external;
}

contract RewardManager is Ownable {
    using SafeMath for uint256;
    
    IROFI private rofi;
    
    uint256 public dailyLimit = 288000 * 10 ** 18;
    
    uint256 public rewardClaimedToday;
    
    uint8 public lockedPercentage = 80;
    
    mapping (address => bool) _callers;
    
    modifier onlyCaller {
        require(_callers[msg.sender] || owner() == msg.sender, "require valid caller");
        _;
    }
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
    }
    
    function setDailyLimit(uint256 _dailyLimit) external onlyOwner {
        dailyLimit = _dailyLimit;
    }
    
    function mintReward(address _to, uint256 _reward) external onlyCaller {
        require(rewardClaimedToday.add(_reward) <= dailyLimit, "exceed daily limit");
        rewardClaimedToday = rewardClaimedToday.add(_reward);
        uint256 locked = uint256(_reward.div(100).mul(lockedPercentage));
        rofi.mintLockedToken(_to, locked);
        rofi.mintUnlockedToken(_to, _reward.sub(locked));
    }
    
    function callers(address _address) external view returns (bool) {
        return _callers[_address];
    }

    function addCaller(address _address) external onlyOwner {
        _callers[_address] = true;
    }
    
    function removeCaller(address _address) external onlyOwner {
        _callers[_address] = false;
    }
    
    function setLockedPercentage(uint8 _percentage) external onlyOwner {
        lockedPercentage = _percentage;
    }
    
    function updateRofi(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
    }
    
    function setRewardClaimedToday(uint256 _value) external onlyOwner {
        rewardClaimedToday = _value;
    }
}