//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);
	
	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IHERO {
    struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}

interface INFT is IERC721, IHERO {
    function getHero(uint256 tokenId_) external view returns (Hero memory);

    function latestTokenId() external view returns(uint);

    function controller() external view returns(address);
}

interface ITicket is IERC721 {
    struct Ticket {
        uint8 star;
    }

    function getTicket(uint256 _ticketId) external view returns (Ticket memory);
}

interface ICNFT {
    function mint(address to, bool _isGenesis, uint8 _star, bytes32 _dna, uint8 _heroType) external;

    function spawn(address to_, uint8 star_) external;
}

interface ILog {
    struct Log {
        bool isSetHeroType;
        uint256 usedTicketID;
        uint256 initAt;
    }
}

interface ILGGateway is ILog {
    function getLog(uint256 _tokenId) external view returns (Log memory);
}

contract LGGateway is IHERO, ILog, Ownable {
    using SafeMath for uint256;

    mapping(uint256 => bool) isSetHeroType;
    mapping(uint256 => uint256) usedTicketID;
    mapping(uint256 => Log) internal logs;

    uint256 private _lastLogId;

    INFT public heroContract;
    INFT public lgContract;
    ICNFT public lgCnftContract;
    ITicket public ticketContract;
    ILGGateway public oldGateway;

    event NewHero(uint256 heroTokenId, uint256 lgTokenId, uint256 ticketId, address indexed owner);

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    uint8 private totalHeroTypes = 10;

    constructor(address _heroContract, address _lgContract, address _ticketContract, address _oldGateway) {
        heroContract = INFT(_heroContract);
        lgContract = INFT(_lgContract);
        lgCnftContract = ICNFT(lgContract.controller());
        ticketContract = ITicket(_ticketContract);
        oldGateway = ILGGateway(_oldGateway);
    }
    
    function generateHeroType(uint256 _tokenId, uint256 _ticketId) external payable {
        require(usedTicketID[_tokenId] == 0, "used ticket"); // Check if used ticket
        require(heroContract.ownerOf(_tokenId) == msg.sender, "not owner of hero"); // Check owner of hero
        require(ticketContract.ownerOf(_ticketId) == msg.sender, "not owner of ticket"); // Check owner of ticket
        uint8 heroStar = heroContract.getHero(_tokenId).star;
        uint8 ticketStar = ticketContract.getTicket(_ticketId).star;
        require(heroStar == ticketStar, "ticket not valid"); // Check hero star and ticket star
        burnTicket(_ticketId);
        usedTicketID[_tokenId] = _ticketId;
        initHero(_tokenId);
    }
    
    function generateHeroTypeNoTicket(uint256 _tokenId) external {
        require(heroContract.ownerOf(_tokenId) == msg.sender, "not owner"); // Check owner of hero
        uint8 heroStar = heroContract.getHero(_tokenId).star;
        require(heroStar == 1, "only 1 star hero"); // Only 1 star hero
        require(!isSetHeroType[_tokenId], "can not re-generate");
        initHero(_tokenId);
    }

    function updateTicketContract(address _newContract) public onlyOwner {
        ticketContract = ITicket(_newContract);
    }

    function initHero(uint256 _tokenId) internal {
        Log memory oldLog = oldGateway.getLog(_tokenId);
        require(!oldLog.isSetHeroType, "used hero token id");
        isSetHeroType[_tokenId] = true;
        uint256 ticketId = usedTicketID[_tokenId];
		logs[_tokenId] = Log({
            isSetHeroType: true,
            usedTicketID: ticketId,
            initAt: block.timestamp
		});
        Hero memory hero = heroContract.getHero(_tokenId);
        address owner = heroContract.ownerOf(_tokenId);
        lgCnftContract.spawn(owner, hero.star);
        uint256 lgTokenId = lgContract.latestTokenId();
        emit NewHero(_tokenId, lgTokenId, ticketId, owner);
    }

    function burnTicket(uint256 _ticketId) internal {
        ticketContract.transferFrom(msg.sender, deadAddress, _ticketId);
    }

    function getLog(uint256 _tokenId) external view returns (Log memory) {
        return logs[_tokenId];
    }

    function getUsedTicketId(uint256 _tokenId) external view returns (uint256) {
        return usedTicketID[_tokenId];
    }

    function updateHeroContract(address _heroContract) external onlyOwner {
        heroContract = INFT(_heroContract);
    }

    function updateLgContract(address _lgContract) external onlyOwner {
        lgContract = INFT(_lgContract);
    }

    function updateLgCnftContract(address _lgCnftContract) external onlyOwner {
        lgCnftContract = ICNFT(_lgCnftContract);
    }

    function updateOldGatewayContract(address _oldGateway) external onlyOwner {
        oldGateway = ILGGateway(_oldGateway);
    }
}