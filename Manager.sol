// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IUseController.sol";

contract Manager is Ownable {
    using SafeMath for uint256;
    
    mapping(address => address) private _controllerOf;

    function _updateManager(
        address target_,
        address manager_
    )
        internal
    {
        IUseController(target_).updateManager(manager_);
    }

    function _updateController(
        address target_,
        address controller_
    )
        internal
    {
        IUseController(target_).updateController(controller_);
        _controllerOf(target_) = controller_;
    }

    function updateManager(
        address target_,
        address controller_
    )
        external
        onlyOwner
    {
        _updateManager(target_, controller_);
    }

    function updateController(
        address target_,
        address controller_
    )
        external
        onlyOwner
    {
        _updateController(target_, controller_);
    }

    function command(address dest_, uint value_, bytes memory data_) external onlyOwner returns (bool success) {
        (success, ) = address(dest_).call{value: value_}(data_);
    }

    function controllerOf(
        address target_
    )
        public
        view
        returns(address controller)
    {
        controller = _controllerOf[target_];
    }
}