//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IROFI {
    function mintUnlockedToken(address to, uint256 amount) external;
    
    function mintLockedToken(address to, uint256 amount) external;
}

contract Reward is Ownable {
    using SafeMath for uint256;
    
    IROFI private rofi;
    
    uint256 public dailyLimit = 288000 * 10 ** 18;
    
    uint256 public rewardClaimedToday;
    
    uint8 public lockedPercentage = 80;
    
    mapping(uint256 => bytes32) roots;
    
    mapping(uint256 => mapping(address => bool)) claimed;
    
    event MerkleRootUpdated(uint256 timestamp, bytes32 merkleRoot);
    
    event RewardClaim(address indexed user, uint256 reward, uint256[] timestamps);
    
    uint256 public claimLimit;
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
    }
    
    function claimReward(uint256 _timestamp, address _user, uint256 _reward, bytes32[] memory _proof) external {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _reward));
        require(MerkleProof.verify(_proof, roots[_timestamp], leaf), "proof not valid");
        require(!claimed[_timestamp][_user], "claimed");
        claimed[_timestamp][_user] = true;
        mintReward(_user, _reward);
        uint256[] memory timestamps = new uint256[](1);
        timestamps[0] = _timestamp;
        emit RewardClaim(_user, _reward, timestamps);
    }
    
    function claimRewards(uint256[] memory _timestamps, address _user, uint256[] memory _rewards, bytes32[][] memory _proofs) public {
        uint256 len = _timestamps.length;
        require(len == _proofs.length, "Mismatching inputs");
        uint256 total = 0;
        for(uint256 i = 0; i < len; i++) {
            bytes32 leaf = keccak256(abi.encodePacked(_user, _rewards[i]));
            require(MerkleProof.verify(_proofs[i], roots[_timestamps[i]], leaf), "proof not valid");
            require(!claimed[_timestamps[i]][_user], "claimed");
            claimed[_timestamps[i]][_user] = true;
            total += _rewards[i];
        }
        mintReward(_user, total);
        emit RewardClaim(_user, total, _timestamps);
    }
    
    function mintReward(address _to, uint256 _reward) internal {
        require(rewardClaimedToday.add(_reward) <= dailyLimit, "exceed daily limit");
        rewardClaimedToday = rewardClaimedToday.add(_reward);
        uint256 locked = uint256(_reward.div(100).mul(lockedPercentage));
        rofi.mintLockedToken(_to, locked);
        rofi.mintUnlockedToken(_to, _reward.sub(locked));
    }
    
    function updateMerkleRoot(uint256 _timestamp, bytes32 _root) external onlyOwner {
        roots[_timestamp] = _root;

        emit MerkleRootUpdated(_timestamp, _root);
    }
    
    function verifyMerkleProof(uint256 _timestamp, address _user, uint256 _reward, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _reward));
        return MerkleProof.verify(_proof, roots[_timestamp], leaf);
    }
    
    function getRoot(uint256 _timestamp) public view returns (bytes32) {
        return roots[_timestamp];
    }
    
    function setDailyLimit(uint256 _dailyLimit) external onlyOwner {
        dailyLimit = _dailyLimit;
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