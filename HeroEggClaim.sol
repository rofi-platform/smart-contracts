//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HeroEggClaim is Ownable {
    using SafeMath for uint256;
    
    IERC20 public token;
    
    uint256 public tranches;
    
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => mapping(address => bool)) public claimed;
    
    event Claimed(address user, uint256 tranche, uint256 balance);
    event TrancheAdded(uint256 tranche, bytes32 merkleRoot, uint256 totalAmount);
    event TrancheExpired(uint256 tranche);
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    function seedNewAllocations(bytes32 _merkleRoot, uint256 _totalAllocation) public onlyOwner returns (uint256 trancheId) {
        token.transferFrom(msg.sender, address(this), _totalAllocation);

        trancheId = tranches;
        merkleRoots[trancheId] = _merkleRoot;

        tranches = tranches.add(1);

        emit TrancheAdded(trancheId, _merkleRoot, _totalAllocation);
    }
    
    function expireTranche(uint256 _trancheId) public onlyOwner {
        merkleRoots[_trancheId] = bytes32(0);

        emit TrancheExpired(_trancheId);
    }
    
    function claimTranche(address _user, uint256 _tranche, uint256 _balance, bytes32[] memory _merkleProof) public {
        _claim(_user, _tranche, _balance, _merkleProof);
        _disburse(_user, _balance);
    }

    function claimTranches(address _user, uint256[] memory _tranches, uint256[] memory _balances, bytes32[][] memory _merkleProofs) public {
        uint256 len = _tranches.length;
        require(len == _balances.length && len == _merkleProofs.length, "Mismatching inputs");

        uint256 totalBalance = 0;
        for(uint256 i = 0; i < len; i++) {
            _claim(_user, _tranches[i], _balances[i], _merkleProofs[i]);
            totalBalance = totalBalance.add(_balances[i]);
        }
        _disburse(_user, totalBalance);
    }
    
    function isClaimed(address _user, uint256 _tranche, uint256 _balance, bytes32[] memory _merkleProof) public view returns (bool) {
        require(_tranche < tranches, "Incorrect tranche");
        
        return claimed[_tranche][_user];
    }

    function verifyClaim(address _user, uint256 _tranche, uint256 _balance, bytes32[] memory _merkleProof) public view returns (bool valid) {
        return _verifyClaim(_user, _tranche, _balance, _merkleProof);
    }
    
    function _claim(address _user, uint256 _tranche, uint256 _balance, bytes32[] memory _merkleProof) private {
        require(_tranche < tranches, "Incorrect tranche");
        require(!claimed[_tranche][_user], "Already claimed");
        require(_verifyClaim(_user, _tranche, _balance, _merkleProof), "Incorrect merkle proof");

        claimed[_tranche][_user] = true;

        emit Claimed(_user, _tranche, _balance);
    }
    
    function _verifyClaim(address _user, uint256 _tranche, uint256 _balance, bytes32[] memory _merkleProof) private view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _balance));
        return MerkleProof.verify(_merkleProof, merkleRoots[_tranche], leaf);
    }
    
    function _disburse(address _user, uint256 _balance) private {
        require(_balance > 0, "No balance would be transferred");
        token.transfer(_user, _balance);
    }
}