//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IROFI {
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    function balanceOf(address account) external view returns (uint256);
}

contract PayRofiUnlocked is Ownable {
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
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
    }
    
    function distributeRofi() external onlyOwner {
        uint256 balance = rofi.balanceOf(address(this));
        uint256 amount = balance.div(100);
        rofi.transfer(address(0x000000000000000000000000000000000000dEaD), amount.mul(burn_percentage));
        rofi.transfer(dev_team_address, amount.mul(dev_team_percentage));
        rofi.transfer(advisor_address, amount.mul(advisor_percentage));
        rofi.transfer(dev_mkt_address, amount.mul(dev_mkt_percentage));
        rofi.transfer(liquidity_address, amount.mul(add_liquidity_percentage));
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