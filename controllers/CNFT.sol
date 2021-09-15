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
    
    mapping (address => bool) _spawners;
    
    modifier onlySpawner {
        require(_spawners[msg.sender] || owner() == msg.sender, "require Spawner");
        _;
    }

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

    function command(address dest_, uint value_, bytes memory data_) external onlyOwner returns (bool success) {
        (success, ) = address(dest_).call{value: value_}(data_);
    }

    function ban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.ban(tokenId_, reason_);
    }

    function unban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.unban(tokenId_, reason_);
    }

    function setBnbFee(uint bnbFee_) external onlyOwner {
        nftContract.setBnbFee(bnbFee_);
    }

    function upgrade(uint256 _tokenId, uint8 _star) external  onlyOwner {
        nftContract.upgrade(_tokenId, _star);
    }

    function genesisSpawn() external payable onlyPaidFee onlyGenesisActive {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        bool _isGenesis = true;
        nftContract.spawn(msg.sender, _isGenesis, uint8(0));
    }

    function spawn(address to_, uint8 star_) external payable onlyPaidFee onlySpawner {
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

    function getTotalHeroTypes() external view returns (uint8) {
        return totalHeroTypes;
    }

    function setTotalHeroTypes(uint8 _totalHeroTypes) external onlyOwner {
        totalHeroTypes = _totalHeroTypes;
    }

    function isGenesisActive()
        public
        view
        returns(bool isActive)
    {
        isActive = _isGenesisActive;
    }
    
    function spawners(address _address) external view returns (bool) {
        return _spawners[_address];
    }
    
    function addSpawner(address _address) external onlyOwner {
        _spawners[_address] = true;
    }
    
    function removeSpawner(address _address) external onlyOwner {
        _spawners[_address] = false;
    }
}