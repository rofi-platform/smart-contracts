// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ManagerInterface.sol";

contract Manager is ManagerInterface, Ownable {
    using SafeMath for uint256;
    
    mapping (address => bool) _spawners;
    
    uint256 internal _priceEgg = 5000*10**18;
    
    function spawners(address _address) external view override returns (bool) {
        return _spawners[_address];
    }
    
    function addSpawner(address _address) public onlyOwner {
        _spawners[_address] = true;
    }
    
    function removeSpawner(address _address) public onlyOwner {
        _spawners[_address] = false;
    }
    
    function priceEgg() external view override returns (uint256) {
        return _priceEgg;
    }
    
    function setPriceEgg(uint256 _price) public onlyOwner {
        _priceEgg = _price;
    }
}