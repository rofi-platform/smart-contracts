// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IHero {
    struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function upgrade(uint256 _tokenId, uint8 _star) external;

    function spawn(address to, bool _isGenesis, uint8 _star) external;

    function latestTokenId() external view returns (uint);
}

interface INFT is IERC721, IHero {
    function getHero(uint256 _tokenId) external view returns (Hero memory);

    function random() external view returns (address);
}

interface ICNFT {
    function spawn(address to_, uint8 star_) external;
}

contract HeroGift is Context, Ownable {

    INFT private nft;

    ICNFT private cnft;

    mapping(address => bool) public receivedHeroGift;

    event GiftHero(address owner, uint256 tokenId);

    modifier onlyPaidFee {
        address random = nft.random();
        random.call{value : msg.value}(new bytes(0));
        _;
    }

    constructor(address _nft, address _cnft) {
        nft = INFT(_nft);
        cnft = ICNFT(_cnft);
    }

    function claimGiftHero() external payable onlyPaidFee {
        require(!receivedHeroGift[_msgSender()], "You received gift hero");
        receivedHeroGift[_msgSender()] = true;
        cnft.spawn(_msgSender(), 1);
        uint256 newTokenId = nft.latestTokenId();
        emit GiftHero(_msgSender(), newTokenId);
    }

    function isReceivedHeroGift(address _user) public view returns (bool) {
        return receivedHeroGift[_user];
    }

    function updateNft(address _newAddress) external onlyOwner {
        nft = INFT(_newAddress);
    }
    
    function updateCnft(address _newAddress) external onlyOwner {
        cnft = ICNFT(_newAddress);
    }
}
