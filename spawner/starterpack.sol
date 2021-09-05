//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface FactoryInterface {
    function spawn(address sender) external;
}

contract StarterPack {
    IERC20 public paymentToken;
    FactoryInterface public factoryContract;

    uint256 public eggPrice = 100000*10**18;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor(address paymentTokenAddress_, address factoryContractAddress_) {
        factoryContract = FactoryInterface(factoryContractAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function spawn() public {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        factoryContract.spawn(msg.sender);
    }
}