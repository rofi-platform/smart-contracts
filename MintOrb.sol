// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IOrbNFT {
    function mintOrb(address to, uint8 _star, uint8 _rarity, uint8 _classType) external;

    function latestOrbId() external view returns (uint256);
}

contract MintOrb is Ownable, Pausable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    IOrbNFT private orbNFT; 

    mapping (bytes32 => bool) public history;

    address public validator;

    uint256 public requestExpire = 300;

    event MintOrbSuccess(address user, uint256 orbId, bytes32 localId);

    constructor(address _orbNFT) {
        orbNFT = IOrbNFT(_orbNFT);
        validator = owner();
    }

    function mintOrb(bytes32 _localId, uint8 _star, uint8 _rarity, uint8 _classType, uint256 _nonce, bytes memory _sign) external whenNotPaused {
        uint256 _now = block.timestamp;
        address user = msg.sender;
        require(_now <= _nonce + requestExpire, "Request expired");
        require(history[_localId] != true, "orb minted");
        bytes32 _hash = keccak256(abi.encodePacked(user, _localId, _star, _rarity, _classType, _nonce));
        _hash = _hash.toEthSignedMessageHash();
        address _signer = _hash.recover(_sign);
        require(_signer == validator, "Invalid sign");
        orbNFT.mintOrb(user, _star, _rarity, _classType);
        uint256 orbId = orbNFT.latestOrbId();
        history[_localId] = true;
        emit MintOrbSuccess(user, orbId, _localId);
    }

    function getOrbNFT() external view returns (address) {
        return address(orbNFT);
    }

    function updateOrbNFT(address _orbNFT) external onlyOwner {
        orbNFT = IOrbNFT(_orbNFT);
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function setExpireTime(uint256 _number) external onlyOwner {
        requestExpire = _number;
    }
}