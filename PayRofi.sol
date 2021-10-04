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
    
    uint8 burn_percentage = 60;
    
    uint8 dev_team_percentage = 18;
    
    uint8 advisor_percentage = 2;
    
    uint8 dev_mkt_percentage = 10;
    
    uint8 add_liquidity_percentage = 10;
    
    IROFI private rofi;
    
    constructor(address _rofi) {
        rofi = IROFI(_rofi);
    }
    
    function payRofi(uint256 _amount) external {
        uint256 amount = _amount.div(100);
        rofi.transferFrom(address(this), address(0), amount.mul(burn_percentage));
        rofi.transferFrom(address(this), dev_team_address, amount.mul(dev_team_percentage));
        rofi.transferFrom(address(this), advisor_address, amount.mul(advisor_percentage));
        rofi.transferFrom(address(this), dev_mkt_address, amount.mul(dev_team_percentage));
        addLiquidity(amount.mul(add_liquidity_percentage));
    }
    
    function addLiquidity(uint256 _amount) internal {
        
    }
    
    function updateRofiAddress(address _newAddress) external onlyOwner {
        rofi = IROFI(_newAddress);
    }
}