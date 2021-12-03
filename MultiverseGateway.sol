//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./modules/NFT/Random-Test.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
	
	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IHERO is IERC721 {
    struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
    function getHero(uint256 tokenId_) external view returns (Hero memory);
}

interface ITicket is IERC721 {
    struct Ticket {
        uint8 star;
    }

    function getTicket(uint256 _ticketId) external view returns (Ticket memory);
}

contract MultiverseGateway is Ownable {
    using SafeMath for uint256;

    mapping(uint256 => uint8) public heroTypes;
    mapping(uint256 => bool) public isSetHeroType;
    mapping(uint256 => uint256) public usedTicketID;

    IHERO public heroContract;
    ITicket public ticketContract; 
    Random private _random;

    event NewHero(uint256 indexed tokenId, uint8 heroType);

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint8 private totalHeroTypes = 10;
    
    modifier onlyRandom {
        require(msg.sender == address(_random), "require Random.");
        _;
    }

    constructor(address _heroContract, address _ticketContract) {
        heroContract = IHERO(_heroContract);
        ticketContract = ITicket(_ticketContract); 
        _random = new Random();
    }

    function getHeroType(uint256 _tokenId) public view returns (uint8) {
        return heroTypes[_tokenId];
    }
    
    function generateHeroType(uint256 _tokenId, uint256 _ticketId) public {
        require(usedTicketID[_tokenId] != 0, "used ticket"); // Check if used ticket
        require(heroContract.ownerOf(_tokenId) == msg.sender, "not owner of hero"); // Check owner of hero
        require(ticketContract.ownerOf(_ticketId) == msg.sender, "not owner of ticket"); // Check owner of ticket
        uint8 heroStar = heroContract.getHero(_tokenId).star;
        uint8 ticketStar = ticketContract.getTicket(_ticketId).star;
        require(heroStar == ticketStar, "ticket not valid"); // Check hero star and ticket star
        burnTicket(_ticketId);

        if (isSetHeroType[_tokenId]) {
            initHero(_tokenId, heroTypes[_tokenId]);
        } else {
            _random.requestRandomNumber(_tokenId);
        }
    }
    
    function generateHeroTypeNoTicket(uint256 _tokenId) public {
        require(heroContract.ownerOf(_tokenId) == msg.sender, "not owner"); // Check owner of hero
        uint8 heroStar = heroContract.getHero(_tokenId).star;
        require(heroStar == 1, "only 1 star hero"); // Only 1 star hero
        require(!isSetHeroType[_tokenId], "can not re-generate");
        _random.requestRandomNumber(_tokenId);
    }

    function random() external view returns(address) {
        return address(_random);
    }
    
    function setBnbFee(uint bnbFee_) external onlyOwner {
        _random.setBnbFee(bnbFee_);
    }
    
    function updateRandom(address payable _newRandom) public onlyOwner {
        _random = Random(_newRandom);
    }

    function updateTicketContract(address _newContract) public onlyOwner {
        ticketContract = ITicket(_newContract);
    }
    
    function submitRandomness(uint _tokenId, uint _randomness) external onlyRandom {
        uint8 heroType = uint8(_randomness.mod(totalHeroTypes).add(1));
        initHero(_tokenId, heroType);
    }

    function initHero(uint256 _tokenId, uint8 _heroType) internal {
        heroTypes[_tokenId] = _heroType;
        isSetHeroType[_tokenId] = true;
        emit NewHero(_tokenId, _heroType);
    }

    function burnTicket(uint256 _ticketId) internal {
        ticketContract.transferFrom(msg.sender, deadAddress, _ticketId);
    }

    function getTotalHeroTypes() external view returns (uint8) {
        return totalHeroTypes;
    }

    function setTotalHeroTypes(uint8 _totalHeroTypes) external onlyOwner {
        totalHeroTypes = _totalHeroTypes;
    }
}