// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUseController {
    function updateController(address controller_) external;
    function updateManager(address manager_) external;
    function controller() external view returns(address);
    function manager() external view returns(address);

    function initController(address controller_) external;
}