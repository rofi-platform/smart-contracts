//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ILog {
    struct Log {
        uint8 newHeroType;
        bool isSetHeroType;
        uint256 usedTicketID;
        uint256 initAt;
    }
}

interface ILGGateway is ILog {
    function getLog(uint256 _tokenId) external view returns (Log memory);
}

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

    function controller() external view returns(address);

    function latestTokenId() external view returns(uint);
}

interface ICNFT {
    function mint(address to, bool _isGenesis, uint8 _star, bytes32 _dna, uint8 _heroType) external;

    function latestTokenId() external view returns(uint);
}

contract HeroMinter is IHERO, ILog, Ownable {
    INFT public herofiNft;

    INFT public lgNft;

    ICNFT public lgCnft;

    ILGGateway public oldGateway;

    mapping(uint256 => bool) public transfered;

    event NewHero(uint256 heroTokenId, uint256 lgTokenId, uint256 ticketId, address indexed owner);

    constructor(address _herofiNft, address _lgNft, address _oldGateway) {
        herofiNft = INFT(_herofiNft);
        lgNft = INFT(_lgNft);
        lgCnft = ICNFT(lgNft.controller());
        oldGateway = ILGGateway(_oldGateway);
    }

    function mint(uint256[] memory _oldIds) external {
        uint256 length = _oldIds.length;
        for (uint256 i = 0; i < length; i++) {
            uint256 oldId = _oldIds[i];
            require(!transfered[oldId], "transfered");
            Log memory log = oldGateway.getLog(oldId);
            require(log.isSetHeroType, "invalid token id");
            Hero memory hero = herofiNft.getHero(oldId);
            address owner = herofiNft.ownerOf(oldId);
            lgCnft.mint(owner, hero.isGenesis, hero.star, hero.dna, log.newHeroType);
            uint256 lgTokenId = lgNft.latestTokenId();
            transfered[oldId] = true;
            emit NewHero(oldId, lgTokenId, log.usedTicketID, owner);
        }
    }
}