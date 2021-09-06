// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TestToken.sol";
import "./Manager.sol";
import "./NFT.sol";
import "./controllers/CNFT.sol";
contract Deployer {
    // 0x0000000000000000000000000000000000000000
    address constant public ZERO_ADDRESS = address(0x0);

    TestToken public token;
    Manager public manager;
    NFT public nft;
    CNFT public controller;

    constructor(
        string memory name_,
        string memory symbol_,
        address paymentToken_
    )
    {
        address sender = msg.sender;
        token = TestToken(paymentToken_);
        if (paymentToken_ == ZERO_ADDRESS) {
            token = new TestToken();
            token.transfer(sender, token.balanceOf(address(this)));
        }

        manager = new Manager();
        manager.transferOwnership(sender);

        nft = new NFT(name_, symbol_, address(manager));
        nft.transferOwnership(sender);

        controller = new CNFT(address(token), address(nft));
        controller.transferOwnership(sender);
    }
    
    function result() public view returns (address _manager, address _nft, address _controller){
        return (address(manager), address(nft), address(controller));
    }
}