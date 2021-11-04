pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract HeroFiTicket is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    
    struct Ticket {
        uint8 star;
    }

    uint256 private _latestTokenId;
    
    IERC20 public paymentToken;
    
    uint256 public ticketPrice = 100000*10**18;
    
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    mapping(uint256 => Ticket) internal tickets;
    
    event BuyTicket(uint256 indexed tokenId, address to);

    constructor(
        address _paymentToken
    ) ERC721("LG-Ticket", "LGTicket") {
        paymentToken = IERC20(_paymentToken);
    }
    
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        
        _incrementTokenId();
    }
    
    function _getNextTokenId() private view returns (uint256) {
        return _latestTokenId.add(1);
    }
    
    function _incrementTokenId() private {
        _latestTokenId++;
    }
    
    function latestTokenId() external view returns(uint) {
        return _latestTokenId;
    }
    
    function buyTicket(uint8 _star) external {
        require(_star >= 1 && _star <= 6, "invalid ticket");
        paymentToken.transferFrom(msg.sender, deadAddress, ticketPrice * _star);
        uint256 nextTokenId = _getNextTokenId();
        _mint(msg.sender, nextTokenId);
        tickets[nextTokenId] = Ticket({
           star: _star 
        });
        emit BuyTicket(nextTokenId, msg.sender);
    }
    
    function setTicketPrice(uint256 _price) external onlyOwner {
        ticketPrice = _price;
    }
}