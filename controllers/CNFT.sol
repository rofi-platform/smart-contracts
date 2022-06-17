//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/INFT.sol";

contract CNFT is Ownable {
    INFT public nftContract;
    
    mapping (address => bool) _spawners;

    mapping (address => bool) _upgraders;
    
    modifier onlySpawner {
        require(_spawners[msg.sender] || owner() == msg.sender, "require Spawner");
        _;
    }

    modifier onlyUpgrader {
        require(_upgraders[msg.sender] || owner() == msg.sender, "require Upgrader");
        _;
    }

    constructor(address nftContractAddress_) {
        bytes4 SELECTOR =  bytes4(keccak256(bytes('initController(address)')));
        nftContractAddress_.call((abi.encodeWithSelector(
            SELECTOR,
            address(this)
        )));

        nftContract = INFT(nftContractAddress_);
    }

    function command(address dest_, uint value_, bytes memory data_) external onlyOwner returns (bool success) {
        (success, ) = address(dest_).call{value: value_}(data_);
    }

    function ban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.ban(tokenId_, reason_);
    }

    function unban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.unban(tokenId_, reason_);
    }

    function upgrade(uint256 _tokenId, uint8 _star) external onlyUpgrader {
        nftContract.upgrade(_tokenId, _star);
    }

    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _plantClass, uint256 _plantId) external onlySpawner {
        nftContract.mint(_to, _star, _rarity, _plantClass, _plantId);
    }
    
    function spawners(address _address) external view returns (bool) {
        return _spawners[_address];
    }
    
    function addSpawner(address _address) external onlyOwner {
        _spawners[_address] = true;
    }
    
    function removeSpawner(address _address) external onlyOwner {
        _spawners[_address] = false;
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

    function updatePlanIds(uint8 _plantClass, uint8 _rarity, uint256[] memory _plantIds) external onlyOwner {
        nftContract.updatePlanIds(_plantClass, _rarity, _plantIds);
    }

    function updateTotalClass(uint8 _totalClass) external onlyOwner {
        nftContract.updateTotalClass(_totalClass);
    }

    function getNft() external view returns (address) {
        return address(nftContract);
    }
}