//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IPEFI {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract ConvertGPEFI is Ownable {
    using SafeMath for uint256;
    
    IPEFI private pefi;
    
    uint256 public dailyLimit = 288000000 * 10 ** 18;
    
    uint256 public convertedToday;
    
    mapping (uint256 => bytes32) roots;
    
    mapping(uint256 => mapping(address => bool)) claimed;
    
    event MerkleRootUpdated(uint256 timestamp, bytes32 merkleRoot);
    
    event ConvertSuccess(address indexed user, uint256 requestId);
    
    uint256 public claimLimit;
    
    constructor(address _pefi) {
        pefi = IPEFI(_pefi);
    }

    function convert(uint256 _timestamp, uint256 _requestId, uint256 _total, uint256 _claimableAt, bytes32[] memory _proof) external {
        address user = msg.sender;
        bytes32 leaf = keccak256(abi.encodePacked(user, _requestId, _total, _claimableAt));
        require(MerkleProof.verify(_proof, roots[_timestamp], leaf), "proof not valid");
        require(!claimed[_timestamp][user], "claimed");
        require(block.timestamp >= _timestamp, "not enough time");
        claimed[_timestamp][user] = true;
        _convert(user, _total);
        emit ConvertSuccess(user, _requestId);
    }
    
    function _convert(address _to, uint256 _total) internal {
        require(convertedToday.add(_total) <= dailyLimit, "exceed daily limit");
        convertedToday = convertedToday.add(_total);
        pefi.transfer(_to, _total);
    }
    
    function updateMerkleRoot(uint256 _timestamp, bytes32 _root) external onlyOwner {
        roots[_timestamp] = _root;

        emit MerkleRootUpdated(_timestamp, _root);
    }

    function verifyMerkleProof(uint256 _timestamp, address _user, uint256 _requestId, uint256 _total, uint256 _claimableAt, bytes32[] memory _proof) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _requestId, _total, _claimableAt));
        return MerkleProof.verify(_proof, roots[_timestamp], leaf);
    }
    
    function getRoot(uint256 _timestamp) public view returns (bytes32) {
        return roots[_timestamp];
    }
    
    function setDailyLimit(uint256 _dailyLimit) external onlyOwner {
        dailyLimit = _dailyLimit;
    }

    function updatePEFI(address _newAddress) external onlyOwner {
        pefi = IPEFI(_newAddress);
    }
    
    function setConvertedToday(uint256 _value) external onlyOwner {
        convertedToday = _value;
    }
}