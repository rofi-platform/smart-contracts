// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IOrbNFT {
    function mintOrb(address to, uint8 _star, uint8 _rarity, uint8 _classType) external;

    function latestOrbId() external view returns (uint256);
}

contract MintOrb is Ownable {
    using SafeMath for uint256;

    IOrbNFT private orbNFT; 

    mapping (address => bool) public managers;

    mapping (bytes32 => bool) public history;

    bytes32 public merkleRoot;

    modifier onlyManager() {
        require(managers[msg.sender], "require: only Manager");
        _;
    }

    event MintOrbSuccess(address user, uint256 orbId, bytes32 localId);

    constructor(address _orbNFT) {
        orbNFT = IOrbNFT(_orbNFT);
    }

    function mintOrb(bytes32 _localId, uint8 _star, uint8 _rarity, uint8 _classType, bytes32[] memory _proof) external {
        address user = msg.sender;
        require(verifyMerkleProof(user, _localId, _star, _rarity, _classType, _proof), "proof not valid");
        require(history[_localId] != true, "orb minted");
        orbNFT.mintOrb(user, _star, _rarity, _classType);
        uint256 orbId = orbNFT.latestOrbId();
        history[_localId] = true;
        emit MintOrbSuccess(user, orbId, _localId);
    }
    
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyManager {
        merkleRoot = _merkleRoot;
    }
    
    function verifyMerkleProof(address _user, bytes32 _localId, uint8 _star, uint8 _rarity, uint8 _classType, bytes32[] memory _proof) public view returns (bool valid) {
        return MerkleProof.verify(_proof, merkleRoot, keccak256(abi.encodePacked(_user, _localId, _star, _rarity, _classType)));
    }

    function getOrbNFT() external view returns (address) {
        return address(orbNFT);
    }

    function updateOrbNFT(address _orbNFT) external onlyOwner {
        orbNFT = IOrbNFT(_orbNFT);
    }

    function addManager(address _manager) external onlyOwner {
        managers[_manager] = true;
    }

    function removeManager(address _manager) external onlyOwner {
        managers[_manager] = false;
    }
}