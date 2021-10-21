pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./modules/NFT/Random-Multiverse.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IHERO {
    struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
    function getHero(uint256 tokenId_) external view returns (Hero memory);
    function ownerOf(uint256 tokenId_) external view returns (address owner);
}

contract Gateway is Ownable{
    mapping(uint256 => bytes32) dnas;
    mapping(uint256 => bool) isSetDna;
    IHERO public hero_contract;
    IERC721 public ticket_contract; 
    Random private _random;

    event NewRandom(address _newRandom);
    
    modifier onlyRandom {
        require(msg.sender == address(_random), "require Random.");
        _;
    }

    constructor(
        address hero_contract_,
        address ticket_contract_
    ){
        hero_contract = IHERO(hero_contract_);
        ticket_contract = IERC721(ticket_contract_); 
        _random = new Random();
    }

    function getDNA(uint256 tokenId_) public view returns (bytes32) {
        return dnas[tokenId_];
    }
    
    function generateDNA(
        uint256 tokenId_, 
        uint256 ticketId1_, 
        uint256 ticketId2_, 
        uint256 ticketId3_, 
        uint256 ticketId4_,
        uint256 ticketId5_,
        uint256 ticketId6_
    ) public {
        // Check if tokenId is belong to owner
        require(hero_contract.ownerOf(tokenId_) == msg.sender, "ROFI: INVALID_HERO_OWNER");
        require(isSetDna[tokenId_] != true, "ROFI: MULTIVERSE_DNA_EXIST");
        uint8 _star = hero_contract.getHero(tokenId_).star;

        if (ticketId1_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId1_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 1");
            _burnTicket(ticketId1_);
        } else {
            return;
        }
        if (ticketId2_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId2_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 2");
            _burnTicket(ticketId2_);
        } else {
            return;
        }
        
        if (ticketId3_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId3_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 3");
            _burnTicket(ticketId3_);
        } else {
            //Check if hero star is 1
            require(_star == 2, "ROFI: REQUIRED_EXACT_TICKET_AMOUNT 2");
            _random.requestRandomNumber(tokenId_);
            return;
        }
        

        if (ticketId4_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId4_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 4");
            _burnTicket(ticketId4_);
        } else {
            //Check if hero star is 1
            require(_star == 3, "ROFI: REQUIRED_EXACT_TICKET_AMOUNT 3");
            _random.requestRandomNumber(tokenId_);
            return;
        }
        
        if (ticketId5_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId5_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 5");
            _burnTicket(ticketId5_);
        } else {
            //Check if hero star is 1
            require(_star == 4, "ROFI: REQUIRED_EXACT_TICKET_AMOUNT 4");
            _random.requestRandomNumber(tokenId_);
            return;
        }

        if (ticketId6_ > 0) {
            // Check if ticketId1 is belong to owner
            require(ticket_contract.ownerOf(ticketId6_) == msg.sender, "ROFI: INVALID_TICKET_OWNER 6");
            _burnTicket(ticketId6_);
        } else {
            //Check if hero star is 1
            require(_star == 5, "ROFI: REQUIRED_EXACT_TICKET_AMOUNT 5");
            _random.requestRandomNumber(tokenId_);
            return;
        }
        _random.requestRandomNumber(tokenId_);
    }
    
    function generateDNA(
        uint256 tokenId_, 
        uint256 ticketId1_, 
        uint256 ticketId2_, 
        uint256 ticketId3_, 
        uint256 ticketId4_,
        uint256 ticketId5_
    ) public {
        generateDNA(tokenId_, ticketId1_, ticketId2_, ticketId3_, ticketId4_, ticketId5_, 0);
    }
    
    function generateDNA(
        uint256 tokenId_, 
        uint256 ticketId1_, 
        uint256 ticketId2_, 
        uint256 ticketId3_, 
        uint256 ticketId4_
    ) public {
        generateDNA(tokenId_, ticketId1_, ticketId2_, ticketId3_, ticketId4_, 0, 0);
    }
    
    function generateDNA(
        uint256 tokenId_, 
        uint256 ticketId1_, 
        uint256 ticketId2_, 
        uint256 ticketId3_
    ) public {
        generateDNA(tokenId_, ticketId1_, ticketId2_, ticketId3_, 0, 0, 0);
    }
    
    function generateDNA(
        uint256 tokenId_, 
        uint256 ticketId1_, 
        uint256 ticketId2_
    ) public {
        generateDNA(tokenId_, ticketId1_, ticketId2_, 0, 0, 0, 0);
    }
    
    function _burnTicket(uint256 ticketId_) internal {
        ticket_contract.transferFrom(msg.sender, address(0x0), ticketId_);
    }

    function random()
        external
        view
        returns(address)
    {
        return address(_random);
    }
    
    function setBnbFee(uint bnbFee_) external onlyOwner {
        _random.setBnbFee(bnbFee_);
    }
    
    function updateRandom(address payable _newRandom) public onlyOwner {
        _random = Random(_newRandom);
        emit NewRandom(_newRandom);
    }
    
    function submitRandomness(uint tokenId_, uint randomness_) external onlyRandom {
        dnas[tokenId_] = bytes32(keccak256(abi.encodePacked(tokenId_, randomness_)));
        isSetDna[tokenId_] = true;
    }
    
}