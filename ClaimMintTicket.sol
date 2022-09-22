// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ClaimMintTicket is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    address public validator;

    uint256 public requestExpire = 300;

    mapping (address => EnumerableSet.UintSet) private records;

    event ClaimSuccess(address user, uint256 timestamp);

    function claim(uint256 _nonce, bytes memory _sign) external {
        address _user = msg.sender;
        uint256 _now = block.timestamp;
        uint256 latest = 0;
        if (records[_user].length() > 0) {
            latest = records[_user].at(records[_user].length().sub(1));
        }
        require(latest == 0 || _now.sub(latest) > requestExpire, "Must wait");
        require(_now <= _nonce + requestExpire, "Request expired");
        bytes32 _hash = keccak256(abi.encodePacked(_user, _nonce));
        _hash = _hash.toEthSignedMessageHash();
        address _signer = _hash.recover(_sign);
        require(_signer == validator, "Invalid sign");
        records[_user].add(_now);
        emit ClaimSuccess(_user, _now);
    }

    function getRecords(address _user) public view returns (uint256[] memory) {
        uint256 length = records[_user].length();
        uint256[] memory data = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            data[i] = records[_user].at(i);
        }
        return data;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function setExpireTime(uint256 _number) external onlyOwner {
        requestExpire = _number;
    }
}