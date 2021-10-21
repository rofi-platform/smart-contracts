pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract HeroFiTicket is ERC721 {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    uint256 private _latestTokenId;

    constructor() ERC721("LG-Ticket", "LGTicket") {}
    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        _incrementTokenId();
    }

    function mint(address to_, uint256 ticketId_) public {
        uint256 nextTokenId = _getNextTokenId();
        _mint(to_, nextTokenId);
    }
    function _getNextTokenId() private view returns (uint256) {
        return _latestTokenId.add(1);
    }
    
    function _incrementTokenId() private {
        _latestTokenId++;
    }
    
    function latestTokenId()
        external
        view
        returns(uint)
    {
        return _latestTokenId;
    }
}