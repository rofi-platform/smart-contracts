//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface CNFT {
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function transferOwnership(address newOwner) external;
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
}

contract WCNFT is Ownable {
    CNFT public cnft;
    
    IERC721 public nft;
    
    mapping (address => bool) _upgraders;
    
    bytes32 public merkleRoot;
    
    event MerkleRootUpdated(bytes32 merkleRoot);
    
    mapping (uint256 => uint256) latestUpgradeStar;
    
    event UpgradeStar(uint256 heroId, uint8 star);
    
    modifier onlyUpgrader {
        require(_upgraders[msg.sender] || owner() == msg.sender, "require Upgrader");
        _;
    }
    
    constructor(address _nft, address _cnft) {
        nft = IERC721(_nft);
        cnft = CNFT(_cnft);
    }
    
    function upgradeStar(uint256 _heroId, uint8 _level, bytes32[] memory _proof, uint8 _star) external {
        require(nft.ownerOf(_heroId) == _msgSender(), "not owner");
        require(latestUpgradeStar[_heroId] == 0 || (block.number - latestUpgradeStar[_heroId]) >= 300, "must wait a least 300 blocks");
        require(_level == 30, "level must be 30");
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _level));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "proof not valid");
        cnft.upgrade(_heroId, _star);
        latestUpgradeStar[_heroId] = block.number;
        emit UpgradeStar(_heroId, _star);
    }
    
    function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootUpdated(merkleRoot);
    }
    
    function verifyMerkleProof(uint256 _heroId, uint8 _level, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_heroId, _level));
        return MerkleProof.verify(_proof, merkleRoot, leaf);
    }
    
    function upgraders(address _address) external view returns (bool) {
        return _upgraders[_address];
    }
    
    function addUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = true;
    }
    
    function removeUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = false;
    }
    
    function transferCNFTOwnership(address newOwner) public onlyOwner {
        cnft.transferOwnership(newOwner);
    }
}