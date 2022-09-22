// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

abstract contract Bannable {
    mapping(address => mapping(uint256 => bool)) private _isBanned;

    modifier onlyNotBanned(address _nft, uint256 _tokenId) {
        require(!_isBanned[_nft][_tokenId], "banned");
        _;
    }

    modifier onlyBanned(address _nft, uint256 _tokenId) {
        require(_isBanned[_nft][_tokenId], "not banned");
        _;
    }

    event Ban(address nft, uint256 tokenId, string reason);

    event Unban(address nft, uint256 tokenId, string reason);

    function _ban(address _nft, uint256 _tokenId, string memory _reason) internal virtual onlyNotBanned(_nft, _tokenId) {
        _isBanned[_nft][_tokenId] = true;
        emit Ban(_nft, _tokenId, _reason);
    }

    function _unban(address _nft, uint256 _tokenId, string memory _reason) internal virtual onlyBanned(_nft, _tokenId) {
        _isBanned[_nft][_tokenId] = false;
        emit Unban(_nft, _tokenId, _reason);
    }
}

abstract contract Controller is Ownable, Pausable, Bannable {
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function ban(address _nft, uint256 _tokenId, string memory _reason) external onlyOwner {
        _ban(_nft, _tokenId, _reason);
    }

    function unban(address _nft, uint256 _tokenId, string memory _reason) external onlyOwner {
        _unban(_nft, _tokenId, _reason);
    }
}

contract NFTMarketplace is Controller {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    event PlaceOrder(
        uint256 indexed orderId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );
    event CancelOrder(
        uint256 indexed orderId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller
    );
    event UpdatePrice(
        uint256 indexed orderId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller,
        uint256 newPrice
    );
    event FillOrder(
        uint256 indexed orderId,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address buyer
    );

    struct ItemSale {
        uint256 orderId;
        address nftAddress;
        uint256 tokenId;
        address owner;
        uint256 price;
    }

    uint256 public currentOrderId;
    uint256 public feeMarketRate = 4; // unit %.
    address public receiver;
    uint256 public minPrice;
    IERC20 public immutable currency;

    mapping(address => bool) public _listedNfts;
    mapping(address => EnumerableSet.UintSet) private tokenSales;
    mapping(address => mapping(uint256 => ItemSale)) internal markets;
    mapping(address => mapping(address => EnumerableSet.UintSet)) private sellerTokens;

    constructor(address _currencyERC20, address _nftListed, address _receiver, uint256 _minPrice){
        currency = IERC20(_currencyERC20);
        _listedNfts[_nftListed] = true;
        receiver = _receiver;
        minPrice = _minPrice;
    }

    modifier onlyListedNft(address _nftAddress) {
        require(_listedNfts[_nftAddress], "ERROR: NFT not accepted in Market");
        _;
    }

    function setFeeMarketRate(uint256 _feeMarketRate) public onlyOwner {
        require(_feeMarketRate < 20, "Too high");
        feeMarketRate = _feeMarketRate;
    }

    function placeOrder(address _nftAddress, uint256 _tokenId, uint256 _price) public onlyListedNft(_nftAddress) {
        require(IERC721(_nftAddress).ownerOf(_tokenId) == _msgSender(), "Not owner of NFT");
        require(_price > 0, "Nothing is free");
        if (minPrice > 0) {
            require(_price >= minPrice, "Must exceed min price");
        }
        tokenOrder(_nftAddress, _tokenId, true, _price);

        emit PlaceOrder(currentOrderId, _nftAddress, _tokenId, _msgSender(), _price);
    }

    function cancelOrder(address _nftAddress, uint256 _tokenId) public onlyListedNft(_nftAddress) {
        require(tokenSales[_nftAddress].contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_nftAddress][_tokenId];
        require(itemSale.owner == _msgSender(), "not own");

        uint256 _orderId = itemSale.orderId;
        tokenOrder(_nftAddress, _tokenId, false, 0);

        emit CancelOrder(_orderId, _nftAddress, _tokenId, _msgSender());
    }

    function updatePrice(address _nftAddress, uint256 _tokenId, uint256 _price) public onlyListedNft(_nftAddress) {
        require(_price > 0, "nothing is free");
        require(tokenSales[_nftAddress].contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_nftAddress][_tokenId];
        require(itemSale.owner == _msgSender(), "not own");

        if (minPrice > 0) {
            require(_price >= minPrice, "Must exceed min price");
        }

        itemSale.price = _price;

        emit UpdatePrice(itemSale.orderId, _nftAddress, _tokenId, _msgSender(), _price);
    }

    function fillOrder(address _nftAddress, uint256 _tokenId, uint256 _price) public onlyListedNft(_nftAddress) {
        require(tokenSales[_nftAddress].contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_nftAddress][_tokenId];
        require(itemSale.price == _price, "Price not match!");
        uint256 feeMarket = itemSale.price.mul(feeMarketRate).div(100);
        if (feeMarket > 0) {
            currency.transferFrom(_msgSender(), receiver, feeMarket);
        }
        currency.transferFrom(
            _msgSender(),
            itemSale.owner,
            itemSale.price.sub(feeMarket)
        );
        uint256 _orderId = itemSale.orderId;
        tokenOrder(_nftAddress, _tokenId, false, 0);
        emit FillOrder(_orderId, _nftAddress, _tokenId, _msgSender());
    }

    function tokenOrder(address _nftAddress, uint256 _tokenId, bool _sell, uint256 _price) internal onlyNotBanned(_nftAddress, _tokenId) {
        ItemSale storage itemSale = markets[_nftAddress][_tokenId];
        if (_sell) {
            IERC721(_nftAddress).transferFrom(_msgSender(), address(this), _tokenId);
            tokenSales[_nftAddress].add(_tokenId);
            sellerTokens[_nftAddress][_msgSender()].add(_tokenId);

            currentOrderId++;
            markets[_nftAddress][_tokenId] = ItemSale({
            orderId : currentOrderId,
            nftAddress : _nftAddress,
            tokenId : _tokenId,
            price : _price,
            owner : _msgSender()
            });
        } else {
            IERC721(_nftAddress).transferFrom(address(this), _msgSender(), _tokenId);
            tokenSales[_nftAddress].remove(_tokenId);
            sellerTokens[_nftAddress][itemSale.owner].remove(_tokenId);
            markets[_nftAddress][_tokenId] = ItemSale({
            orderId : 0,
            nftAddress : address(0),
            tokenId : 0,
            price : 0,
            owner : address(0)
            });
        }
    }

    function orders(address _nftAddress, address _seller) public view returns (uint256) {
        return sellerTokens[_nftAddress][_seller].length();
    }

    function tokenSaleByIndex(address _nftAddress, uint256 index) public view returns (uint256) {
        return tokenSales[_nftAddress].at(index);
    }

    function tokensSaleOfOwner(address _nftAddress, address _seller) public view returns (uint256[] memory) {
        return sellerTokens[_nftAddress][_seller].values();
    }

    function getSale(address _nftAddress, uint256 _tokenId) public view returns (ItemSale memory) {
        if (tokenSales[_nftAddress].contains(_tokenId)) return markets[_nftAddress][_tokenId];
        return ItemSale({orderId : 0, nftAddress : address(0), tokenId : 0, owner : address(0), price : 0});
    }

    function listNft(address _nftAddress) external onlyOwner {
        _listedNfts[_nftAddress] = true;
    }

    function delistNft(address _nftAddress) external onlyOwner {
        _listedNfts[_nftAddress] = false;
    }

    function setMinPrice(uint256 _minPrice) external onlyOwner {
        minPrice = _minPrice;
    }

    function setReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }
}