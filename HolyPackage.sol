// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract HolyPackage is ERC721, Ownable, Pausable {
    using SafeMath for uint256;
    using ECDSA for bytes32;

    struct Package {
        string holyType;
        uint256 createdAt;
    }

    uint256 private _latestPackageId;

    uint256 private holyRequired = 5;

    uint256 private requiredTime = 60*60*4;

    uint256 public requestExpire = 300;

    address public validator;

    mapping (uint256 => Package) public packages;

    mapping (address => uint256) private history;

    mapping (address => bool) whitelistSenders;

    mapping (address => bool) whitelistReceivers;

    event NewPackage(address user, uint256 packageId, string holyType, uint256 createdAt);

    constructor() ERC721("Holy Package", "HOLYPACKAGE") {
        validator = owner();
    }

    function _mint(address to, uint256 packageId) internal override(ERC721) {
        super._mint(to, packageId);
        
        _incrementPackageId();
    }

    function mint(uint256 _quantity, string memory _holyType, uint256 _nonce, bytes memory _sign) external whenNotPaused {
        uint256 _now = block.timestamp;
        address _user = msg.sender;
        require(_now <= _nonce + requestExpire, "Request expired");
        require(history[_user] == 0 || (block.timestamp - history[_user]) >= requiredTime, "Must wait");
        require(_quantity >= holyRequired && _quantity.mod(holyRequired) == 0, "quantity not valid");
        bytes32 _hash = keccak256(abi.encodePacked(_user, _quantity, _holyType, _nonce));
        _hash = _hash.toEthSignedMessageHash();
        address _signer = _hash.recover(_sign);
        require(_signer == validator, "Invalid sign");
        uint256 times = _quantity.div(holyRequired);
        uint256 run = 0;
        while (run < times) {
            _mintPackage(_user, _holyType);
            run++;
        }
        history[_user] = block.timestamp;
    }

    function _mintPackage(address _user, string memory _holyType) internal {
        uint256 nextPackageId = _getNextPackageId();
        _mint(_user, nextPackageId);
        packages[nextPackageId] = Package({
            holyType: _holyType,
            createdAt: block.timestamp
        });
        emit NewPackage(_user, nextPackageId, _holyType, block.timestamp);
    }

    function getPackage(uint256 _packageId) public view returns (Package memory) {
        return packages[_packageId];
    }

    function latestPackageId() external view returns (uint256) {
        return _latestPackageId;
    }

    function _getNextPackageId() private view returns (uint256) {
        return _latestPackageId.add(1);
    }
    
    function _incrementPackageId() private {
        _latestPackageId++;
    }

    function getHolyRequired() external view returns (uint256) {
        return holyRequired;
    }

    function updateHolyRequired(uint256 _number) external onlyOwner {
        holyRequired = _number;
    }

    function getRequiredTime() external view returns (uint256) {
        return requiredTime;
    }

    function updateRequiredTime(uint256 _number) external onlyOwner {
        requiredTime = _number;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function setExpireTime(uint256 _number) external onlyOwner {
        requestExpire = _number;
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(whitelistSenders[from] || whitelistReceivers[to], "not whitelist");
        super._transfer(from, to, tokenId);
    }

    function isWhitelistSender(address _address) public view returns (bool) {
        return whitelistSenders[_address];
    }

    function addWhitelistSender(address _address) public onlyOwner {
        whitelistSenders[_address] = true;
    }

    function removeWhitelistSender(address _address) public onlyOwner {
        whitelistSenders[_address] = false;
    }

    function isWhitelistReceiver(address _address) public view returns (bool) {
        return whitelistReceivers[_address];
    }

    function addWhitelistReceiver(address _address) public onlyOwner {
        whitelistReceivers[_address] = true;
    }

    function removeWhitelistReceiver(address _address) public onlyOwner {
        whitelistReceivers[_address] = false;
    }
}