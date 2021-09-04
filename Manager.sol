// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ManagerInterface.sol";

contract Manager is ManagerInterface, Ownable {
    using SafeMath for uint256;
    
    mapping (address => bool) _spawners;
    
    mapping (address => bool) _upgraders;
    
    uint8 internal _totalHeroTypes = 6;
    
    function spawners(address _address) external view override returns (bool) {
        return _spawners[_address];
    }
    
    function addSpawner(address _address) public onlyOwner {
        _spawners[_address] = true;
    }
    
    function removeSpawner(address _address) public onlyOwner {
        _spawners[_address] = false;
    }
    
    function upgraders(address _address) external view override returns (bool) {
        return _upgraders[_address];
    }
    
    function addUpgrader(address _address) public onlyOwner {
        _upgraders[_address] = true;
    }
    
    function removeUpgrader(address _address) public onlyOwner {
        _upgraders[_address] = false;
    }
    
    function totalHeroTypes() external view override returns (uint8) {
        return _totalHeroTypes;
    }
    
    function setTotalHeroTypes(uint8 totalHeroTypes_) public onlyOwner {
        _totalHeroTypes = totalHeroTypes_;
    }
    
    function command(address dest_, uint value_, bytes memory data_) external onlyOwner returns (bool success) {
        (success, ) = address(dest_).call{value: value_}(data_);
    }
}