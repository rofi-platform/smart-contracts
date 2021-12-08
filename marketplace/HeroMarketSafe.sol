pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IItemSale {
    struct ItemSale {
        uint256 orderId;
        address nftAddress;
        uint256 tokenId;
        address owner;
        uint256 price;
    }
}

interface IHeroMarket is IItemSale {
    function fillOrder(address _nftAddress, uint256 _tokenId) external;

    function getSale(address _nftAddress, uint256 _tokenId) external view returns (ItemSale memory);
}


contract HeroMarketSafe is Context, IItemSale {
    IHeroMarket public immutable heroMarket;
    IERC20 public immutable busd;

    constructor(address _heroMarket, address _busd){
        heroMarket = IHeroMarket(_heroMarket);
        busd = IERC20(_busd);
        uint256 MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        busd.approve(_heroMarket, MAX_INT);
    }

    function fillOrder(address _nftAddress, uint256 _tokenId, uint256 _price) public {
        ItemSale memory order = heroMarket.getSale(_nftAddress, _tokenId);
        require(order.price == _price, "Price not match!");
        busd.transferFrom(_msgSender(), address(this), _price);
        heroMarket.fillOrder(_nftAddress, _tokenId);
        IERC721(_nftAddress).transferFrom(address(this), _msgSender(), _tokenId);

    }
}
