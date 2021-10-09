//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface INFT {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IROFI {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract QuestReward is Ownable {
    INFT private nft;
    
    IROFI private rofi;
    
    address private payRofi;
    
    bytes32 public merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    struct Quest {
        uint8 mapToWin;
        uint256 reward;
    }
    
    uint8 latestQuestId = 0;
    
    mapping (uint8 => Quest) quests;
    
    mapping (uint256 => mapping(uint8 => bool)) rewardClaimed;
    
    event RewardClaim(uint256 heroId, uint8 questId, uint256 reward);
    
    constructor(address _nft, address _rofi) {
        nft = INFT(_nft);
        rofi = IROFI(_rofi);
    }
    
    function claimReward(uint256 _heroId, uint8 _questId, uint8 _mapCompleted, bytes32[] memory _proof) external {
        require(nft.ownerOf(_heroId) == _msgSender(), "not owner");
        require(!rewardClaimed[_heroId][_questId], "quest reward claimed");
        Quest memory quest = quests[_questId];
        require(_mapCompleted >= quest.mapToWin, "not complete enough map");
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _questId, _mapCompleted));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "proof not valid");
        uint256 reward = quest.reward;
        rewardClaimed[_heroId][_questId] = true;
        rofi.transfer(_msgSender(), reward);
        emit RewardClaim(_heroId, _questId, reward);
    }
    
    function addQuest(uint8 _map, uint256 _reward) public onlyOwner {
        uint8 questId = latestQuestId + 1;
        quests[questId] = Quest({
            mapToWin: _map,
            reward: _reward
        });
        latestQuestId++;
    }
    
    function getQuest(uint8 _questId) public view returns (Quest memory) {
        return quests[_questId];
    }
    
    function updateQuestReward(uint8 _questId, uint256 _reward) public onlyOwner {
        Quest storage quest = quests[_questId];
        quest.reward = _reward;
    }
    
    function updateQuestMap(uint8 _questId, uint8 _mapToWin) public onlyOwner {
        Quest storage quest = quests[_questId];
        quest.mapToWin = _mapToWin;
    }
    
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(uint256 _heroId, uint8 _questId, uint8 _mapCompleted, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _questId, _mapCompleted));
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }
    
    function updateNft(address _newAddress) external onlyOwner {
        nft = INFT(_newAddress);
    }
    
    function updateRofi(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
    }
}