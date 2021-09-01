// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ManagerInterface {
    function spawners(address _address) external view returns (bool);
    
    function upgraders(address _address) external view returns (bool);
    
    function totalHeroTypes() external view returns (uint8);
}