//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IRewardManager {
    function mintReward(address _to, uint256 _reward) external;
}

contract RewardTOB is Ownable {
    IRewardManager private rewardManager;
    
    mapping(uint256 => bytes32) roots;
    
    mapping(uint256 => mapping(address => bool)) claimed;
    
    event MerkleRootUpdated(uint256 timestamp, bytes32 merkleRoot);
    
    event RewardClaim(address user, uint256 reward, uint256 timestamp);
    
    uint256 public claimLimit;
    
    constructor(address _rewardManager) {
        rewardManager = IRewardManager(_rewardManager); 
        claimLimit = 10000 * 10 ** 18;
    }
    
    function claimReward(uint256 _timestamp, address _user, uint256 _reward, bytes32[] memory _proof) external {
        require(_reward <= claimLimit, "exceed claim limit");
        uint256 current = block.timestamp;
        require((current - _timestamp) <= 10 days, "must claim within 10 days");
        bytes32 leaf = keccak256(abi.encodePacked(_user, _reward));
        // require(MerkleProof.verify(_proof, roots[_timestamp], leaf), "proof not valid");
        require(!claimed[_timestamp][_user], "claimed");
        claimed[_timestamp][_user] = true;
        rewardManager.mintReward(_user, _reward);
        emit RewardClaim(_user, _reward, _timestamp);
    }
    
    function updateMerkleRoot(uint256 _timestamp, bytes32 _root) external onlyOwner {
        roots[_timestamp] = _root;

        emit MerkleRootUpdated(_timestamp, _root);
    }
    
    function verifyMerkleProof(uint256 _timestamp, address _user, uint256 _reward, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _reward));
        return MerkleProof.verify(_proof, roots[_timestamp], leaf);
    }
    
    function updateRewardManager(address _newAddress) external onlyOwner {
        rewardManager = IRewardManager(_newAddress);
    }
    
    function getRoot(uint256 _timestamp) public view returns (bytes32) {
        return roots[_timestamp];
    }
    
    function setClaimLimit(uint256 _claimLimit) external onlyOwner {
        claimLimit = _claimLimit;
    }
}