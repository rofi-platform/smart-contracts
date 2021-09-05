//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/INFT.sol";

contract CNFT is Ownable {
    modifier onlyPaidFee {
        address random = nftContract.random();
        random.call{value: msg.value}(new bytes(0));
        _;
    }
    IERC20 public paymentToken;
    INFT public nftContract;

    uint256 public eggPrice = 100000*10**18;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor(
        address paymentTokenAddress_,
        address nftContractAddress_
    )
    {
        bytes4 SELECTOR =  bytes4(keccak256(bytes('initController(address)')));
        nftContractAddress_.call((abi.encodeWithSelector(
            SELECTOR,
            address(this)
        )));

        nftContract = INFT(nftContractAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function setBnbFee(uint bnbFee_) external onlyOwner {
        nftContract.setBnbFee(bnbFee_);
    }

    function genesisSpawn() external payable onlyPaidFee {
        nftContract.spawn(msg.sender, true);
    }

    function spawn() external payable onlyPaidFee {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        nftContract.spawn(msg.sender, false);
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