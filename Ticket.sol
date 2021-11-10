pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract LGEssenceTicket is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    
    struct Ticket {
        uint8 star;
    }

    uint256 private _latestTokenId;
    
    IERC20 public paymentToken;
    
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    
    mapping (uint256 => Ticket) internal tickets;
    
    mapping (uint8 => uint256) ticketFees;
    
    event BuyTicket(uint256 indexed tokenId, address to);

    constructor(
        address _paymentToken
    ) ERC721("LG Essence Ticket", "LGESSENCE") {
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
        require(_star >= 2 && _star <= 6, "invalid ticket");
        paymentToken.transferFrom(msg.sender, deadAddress, ticketFees[_star]);
        uint256 nextTokenId = _getNextTokenId();
        _mint(msg.sender, nextTokenId);
        tickets[nextTokenId] = Ticket({
           star: _star 
        });
        emit BuyTicket(nextTokenId, msg.sender);
    }
    
    function getTicket(uint256 _ticketId) public view returns (Ticket memory) {
        return tickets[_ticketId];
    }
    
    function updateFee(uint8[] memory _stars, uint256[] memory _fees) external onlyOwner {
        uint256 length = _stars.length;
        require(length == _fees.length, "params not correct");
        for (uint256 i = 0; i < length; i++) {
            uint8 _star = uint8(_stars[i]);
            ticketFees[_star] = uint256(_fees[i]*10**18);
        }
    }
    
    function getFee(uint8 _star) public view returns (uint256) {
        return ticketFees[_star];
    }
    
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = IERC20(_paymentToken);
    }
}