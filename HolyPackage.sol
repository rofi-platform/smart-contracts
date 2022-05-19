// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract HolyPackage is ERC721, Ownable {
    using SafeMath for uint256;

    struct Package {
        uint8 holyType;
        uint256 createdAt;
    }

    uint256 private _latestPackageId;

    uint256 private holyRequired = 5;

    uint256 private requiredTime = 60*60*4;

    mapping (uint256 => Package) public packages;

    mapping (address => uint256) private history;

    mapping (address => bool) public managers;

    bytes32 public merkleRoot;

    modifier onlyManager() {
        require(managers[msg.sender], "require: only Manager");
        _;
    }

    event NewPackage(address user, uint256 packageId, uint8 holyType, uint256 createdAt);

    constructor() ERC721("Holy Package", "HOLYPACKAGE") {

    }

    function _mint(address to, uint256 packageId) internal override(ERC721) {
        super._mint(to, packageId);
        
        _incrementPackageId();
    }

    function mint(address _to, uint256 _quantity, uint256 _total, uint8 _holyType, bytes32[] memory _proof) external {
        require(history[_to] == 0 || (block.timestamp - history[_to]) >= requiredTime, "must wait");
        require(verifyMerkleProof(_to, _total, _holyType, _proof), "proof not valid");
        require(_quantity <= _total && _quantity >= holyRequired && _quantity.mod(holyRequired) == 0, "quantity not valid");
        uint256 times = _quantity.div(holyRequired);
        uint256 run = 0;
        while (run < times) {
            _mintPackage(_to, _holyType);
            run++;
        }
        history[_to] = block.timestamp;
    }

    function _mintPackage(address _user, uint8 _holyType) internal {
        uint256 nextPackageId = _getNextPackageId();
        _mint(_user, nextPackageId);
        packages[nextPackageId] = Package({
            holyType: _holyType,
            createdAt: block.timestamp
        });
        emit NewPackage(_user, nextPackageId, _holyType, block.timestamp);
    }

    function addManager(address _manager) external onlyOwner {
        managers[_manager] = true;
    }

    function removeManager(address _manager) external onlyOwner {
        managers[_manager] = false;
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

    function updateMerkleRoot(bytes32 _merkleRoot) external onlyManager {
        merkleRoot = _merkleRoot;
    }
    
    function verifyMerkleProof(address _user, uint256 _quantity, uint8 _holyType, bytes32[] memory _proof) public view returns (bool valid) {
        return MerkleProof.verify(_proof, merkleRoot, keccak256(abi.encodePacked(_user, _quantity, _holyType)));
    }
}