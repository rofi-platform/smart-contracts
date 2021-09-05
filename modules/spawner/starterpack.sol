//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface FactoryInterface {
    function spawn(address sender) external;
    function random() external view returns(address);
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

    function spawn() public payble {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        address random = factoryContract.random();
        (bool success,) = random.call{value: msg.value}(new bytes(0));
        require(success, "bnb fee required!");
        factoryContract.spawn(msg.sender);
    }
}