//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ICNFT";

interface FactoryInterface {
    function spawn(address sender) external;
}

contract CNFT is ICNFT {
    IERC20 public paymentToken;
    FactoryInterface public factoryContract;

    uint256 public eggPrice = 100000*10**18;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor(address paymentTokenAddress_, address factoryContractAddress_) {
        factoryContract = FactoryInterface(factoryContractAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function spawn() external payable {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        factoryContract.spawn(msg.sender);
    }

    function getStarFromRandomness(uint256 _randomness) external pure returns(uint8) {
        uint seed = _randomness % 100;
        if (seed < 65) {
            return 3;
        }
        if (seed < 90) {
            return 4;
        }
        if (seed < 98) {
            return 5;
        }
        return 6;
    }

    function getTotalHeroTypes() external pure returns (uint8) {
        return 6;
    }
}