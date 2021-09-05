//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IManager {
    function owner() external view returns (address);
    function updateManager(
        address target_,
        address controller_
    )
        external;

    function updateController(
        address target_,
        address controller_
    )
        external;

    function command(
        address dest_,
        uint value_,
        bytes memory data_
    )
        external
        returns(bool success);

    function controllerOf(
        address target_
    )
        external
        view
        returns(address controller);
}