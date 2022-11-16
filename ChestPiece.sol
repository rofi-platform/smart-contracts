// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ChestPiece is Ownable, ERC721 {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter public currentTokenId;

    struct Info {
        address owner;
        uint8 chestType;
        uint256 createdAt;
    }

    mapping (address => bool) public minters;

    mapping (uint256 => Info) public chestPieces;

    mapping (address => bool) whitelistSenders;

    mapping (address => bool) whitelistReceivers;

    modifier onlyMinter() {
        require(minters[msg.sender], "require: only minter");
        _;
    }

    constructor() ERC721("PE Chest Piece", "PECHESTPIECE") {

    }

    function _mint(address _to, uint256 _tokenId) internal override(ERC721) {
        super._mint(_to, _tokenId);
        currentTokenId.increment();
    }

    function mint(address _to, uint8 _chestType, uint8 _amount) external onlyMinter {
        uint8 time = 0;
        while (time < _amount) {
            _mintChestPiece(_to, _chestType);
            time++;
        }
    }

    function _mintChestPiece(address _to, uint8 _chestType) internal {
        uint256 tokenId = currentTokenId.current();
        _mint(_to, tokenId);
        chestPieces[tokenId] = Info({
            owner: _to,
            chestType: _chestType,
            createdAt: block.timestamp
        });
    }

    function addMinter(address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function getChestPiece(uint256 _tokenId) public view returns (Info memory) {
        return chestPieces[_tokenId];
    }

    function latestTokenId() public view returns (uint256) {
        return currentTokenId.current();
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        require(whitelistSenders[from] || whitelistReceivers[to], "not whitelist");
        super._transfer(from, to, tokenId);
    }

    function isWhitelistSender(address _address) public view returns (bool) {
        return whitelistSenders[_address];
    }

    function addWhitelistSender(address _address) public onlyOwner {
        whitelistSenders[_address] = true;
    }

    function removeWhitelistSender(address _address) public onlyOwner {
        whitelistSenders[_address] = false;
    }

    function isWhitelistReceiver(address _address) public view returns (bool) {
        return whitelistReceivers[_address];
    }

    function addWhitelistReceiver(address _address) public onlyOwner {
        whitelistReceivers[_address] = true;
    }

    function removeWhitelistReceiver(address _address) public onlyOwner {
        whitelistReceivers[_address] = false;
    }
}