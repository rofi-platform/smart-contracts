// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Manager.sol";
import "./NFT.sol";
import "./controllers/CNFT.sol";

contract Deployer {
    address constant public ZERO_ADDRESS = address(0x0);

    Manager public manager;
    NFT public nft;
    CNFT public controller;

    constructor(string memory name_, string memory symbol_) {
        address sender = msg.sender;

        manager = new Manager();
        manager.transferOwnership(sender);

        nft = new NFT(name_, symbol_, address(manager));
        nft.transferOwnership(sender);

        controller = new CNFT(address(nft));
        controller.transferOwnership(sender);
    }
    
    function result() public view returns (address _manager, address _nft, address _controller){
        return (address(manager), address(nft), address(controller));
    }
}