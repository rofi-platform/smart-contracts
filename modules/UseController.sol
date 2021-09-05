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

    // fixed
    address private _manager;
    // changeable
    address private _controller;

    constructor(
        address manager_,
        address initController_
    )
    {
        _manager = manager_;
        _updateController(initController_);
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