pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract HeroFiTicket is ERC721 {
    constructor() ERC721("LG-Ticket", "LGTicket") {}
    function mint(address to_, uint256 ticketId_) public {
        _mint(to_, ticketId_);
    }
}