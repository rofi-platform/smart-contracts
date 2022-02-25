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

interface IItemSale {
    struct ItemSale {
        uint256 orderId;
        address nftAddress;
        uint256 tokenId;
        address owner;
        uint256 price;
    }
}

interface IMarket is IItemSale {
    function getSale(address _nftAddress, uint256 _tokenId) external view returns (ItemSale memory);
}

interface IBreed {
    struct Breed {
		address owner;
		uint256 tokenId1;
		uint256 tokenId2;
		uint8 newHeroStar;
		uint256 breedingPeriod;
		uint256 startAt;
	}
}

interface IBreeding is IBreed {
    function getBreed(uint256 _breedId) external view returns (Breed memory);
}

contract FixHeroMinter is Ownable, IItemSale, IHERO, ILog, IBreed {
    INFT public herofiNft;

    INFT public lgNft;

    ICNFT public lgCnft;

    ILGGateway public oldGateway;

    IMarket public market;

    IBreeding public breeding;

    mapping(uint256 => bool) public transfered;

    event NewHero(uint256 heroTokenId, uint256 lgTokenId, uint256 ticketId, address indexed owner);

    constructor(address _herofiNft, address _lgNft, address _oldGateway, address _market, address _breeding) {
        herofiNft = INFT(_herofiNft);
        lgNft = INFT(_lgNft);
        lgCnft = ICNFT(lgNft.controller());
        oldGateway = ILGGateway(_oldGateway);
        market = IMarket(_market);
        breeding = IBreeding(_breeding);
    }

    function run(uint256[] memory _tokenIds, bool[] memory _isSells, uint256[] memory _breedIds) external {
        uint256 length = _tokenIds.length;
        require(length == _isSells.length && length == _breedIds.length, "invalid params");
        for (uint256 i = 0; i < length; i++) {
            if (_isSells[i]) {
                ItemSale memory itemSale = market.getSale(address(herofiNft), _tokenIds[i]);
                if (itemSale.owner == address(0)) {
                    address newOwner = herofiNft.ownerOf(_tokenIds[i]);
                    mint(newOwner, _tokenIds[i]);
                } else {
                    mint(itemSale.owner, _tokenIds[i]);
                }
            } else {
                Breed memory breed = breeding.getBreed(_breedIds[i]);
                mint(breed.owner, _tokenIds[i]);
            }
        }
    }

    function mint(address owner, uint256 oldId) internal {
        require(!transfered[oldId], "transfered");
        Log memory log = oldGateway.getLog(oldId);
        require(log.isSetHeroType, "invalid token id");
        Hero memory hero = herofiNft.getHero(oldId);
        lgCnft.mint(owner, hero.isGenesis, hero.star, hero.dna, log.newHeroType);
        uint256 lgTokenId = lgNft.latestTokenId();
        transfered[oldId] = true;
        emit NewHero(oldId, lgTokenId, log.usedTicketID, owner);
    }
}