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

    modifier onlyGenesisActive {
        require(_isGenesisActive, "CNFT: genesis spawn disabled!");
        _;
    }

    IERC20 public paymentToken;
    INFT public nftContract;

    uint256 public eggPrice = 100000*10**18;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    bool private _isGenesisActive = true;

    uint8 private totalHeroTypes = 6;

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

    function setGenesisActive(
        bool isActive_
    )
        external
        onlyOwner
    {
        _isGenesisActive = isActive_;
    }

    function setBnbFee(uint bnbFee_) external onlyOwner {
        nftContract.setBnbFee(bnbFee_);
    }

    function genesisSpawn() external payable onlyPaidFee onlyGenesisActive {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        bool _isGenesis = true;
        nftContract.spawn(msg.sender, _isGenesis, uint8(0));
    }

    function spawn(address to_, uint8 star_) external payable onlyPaidFee onlyOwner {
        bool _isGenesis = false;
        nftContract.spawn(to_, _isGenesis, star_);
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
        return totalHeroTypes;
    }

    function setGenesisActive(uint8 _totalHeroTypes) external onlyOwner {
        totalHeroTypes = _totalHeroTypes;
    }

    function isGenesisActive()
        public
        view
        returns(bool isActive)
    {
        isActive = _isGenesisActive;
    }
}