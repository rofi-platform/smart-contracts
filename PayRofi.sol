//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IROFI {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract PayRofi is Ownable {
    using SafeMath for uint256;
    
    address public dev_team_address;
    
    address public advisor_address;
    
    address public dev_mkt_address;
    
    address public liquidity_address;
    
    uint8 public burn_percentage = 60;
    
    uint8 public dev_team_percentage = 18;
    
    uint8 public advisor_percentage = 2;
    
    uint8 public dev_mkt_percentage = 10;
    
    uint8 public add_liquidity_percentage = 10;
    
    IROFI private rofi;
    
    mapping (address => bool) _callers;
    
    modifier onlyCaller {
        require(_callers[msg.sender] || owner() == msg.sender, "require valid caller");
        _;
    }
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
    }
    
    function callers(address _address) external view returns (bool) {
        return _callers[_address];
    }

    function addCaller(address _address) external onlyOwner {
        _callers[_address] = true;
    }
    
    function removeCaller(address _address) external onlyOwner {
        _callers[_address] = false;
    }
    
    function payRofi(address _sender, uint256 _amount) external onlyCaller {
        uint256 amount = _amount.div(100);
        rofi.transferFrom(_sender, address(0x000000000000000000000000000000000000dEaD), amount.mul(burn_percentage));
        rofi.transferFrom(_sender, dev_team_address, amount.mul(dev_team_percentage));
        rofi.transferFrom(_sender, advisor_address, amount.mul(advisor_percentage));
        rofi.transferFrom(_sender, dev_mkt_address, amount.mul(dev_mkt_percentage));
        rofi.transferFrom(_sender, liquidity_address, amount.mul(add_liquidity_percentage));
    }
    
    function updateRofiAddress(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
    }
    
    function updateDevTeamAddress(address _newAddress) external onlyOwner {
        dev_team_address = _newAddress;
    }
    
    function updateAdvisorAddress(address _newAddress) external onlyOwner {
        advisor_address = _newAddress;
    }
    
    function updateDevMktAddress(address _newAddress) external onlyOwner {
        dev_mkt_address = _newAddress;
    }
    
    function updateLiquidityAddress(address _newAddress) external onlyOwner {
        liquidity_address = _newAddress;
    }
    
    function setBurnPercentage(uint8 _percentage) external onlyOwner {
        burn_percentage = _percentage;    
    }
    
    function setDevTeamPercentage(uint8 _percentage) external onlyOwner {
        dev_team_percentage = _percentage;    
    }
    
    function setAdvisorPercentage(uint8 _percentage) external onlyOwner {
        advisor_percentage = _percentage;    
    }
    
    function setDevMktPercentage(uint8 _percentage) external onlyOwner {
        dev_mkt_percentage = _percentage;    
    }
    
    function setAddLiquidityPercentage(uint8 _percentage) external onlyOwner {
        add_liquidity_percentage = _percentage;    
    }
    
}