//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract UseController {
    event UpdateController(address controller);
    event UpdateManager(address manager);

    modifier onlyManager()
    {
        require(msg.sender == _manager, "UseController: permission denied!");
        _;
    }

    modifier onlyController()
    {
        require(msg.sender == _controller, "UseController: permission denied!");
        _;
    }

    address constant private ZERO_ADDRESS = address(0x0);

    // fixed
    address private _manager;
    // changeable
    address private _controller = ZERO_ADDRESS;

    constructor(
        address manager_
    )
    {
        _manager = manager_;
    }

    function _updateManager(
        address manager_
    )
        internal
    {
        _manager = manager_;
        emit UpdateManager(manager_);
    }

    function _updateController(
        address controller_
    )
        internal
    {
        _controller = controller_;
        emit UpdateController(controller_);
    }

    /*
        public
    */

    function initController(
        address controller_
    )
        external
    {
        require(_controller == ZERO_ADDRESS, "UseController: already set!");
        _updateController(controller_);
    }

    function updateManager(
        address manager_
    )
        external
        onlyManager
    {
        _updateManager(manager_);
    }

    function updateController(
        address controller_
    )
        external
        onlyManager
    {
        _updateController(controller_);
    }

    function controller()
        public
        view
        returns(address)
    {
        return _controller;
    }

    function manager()
        public
        view
        returns(address)
    {
        return _manager;
    }
}