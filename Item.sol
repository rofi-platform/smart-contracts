// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ItemNFT is ERC721, Ownable {
    using SafeMath for uint256;

    struct Item {
        uint8 star;
        uint256 itemType;
        uint256 bornAt;
        uint256 lastUpdate;
    }

    uint256 private _latestItemId;

    mapping (uint256 => Item) public items;

    mapping (uint8 => uint256[]) public starToTypes;

    mapping (address => bool) public minters;

    mapping (address => bool) public updaters;

    modifier onlyMinter() {
        require(minters[msg.sender], "require: only Minter");
        _;
    }

    modifier onlyUpdater() {
        require(updaters[msg.sender], "require: only Updaters");
        _;
    }

    event NewItem(uint256 itemId, uint8 star, uint256 itemType, uint256 bornAt, uint256 lastUpdate);

    event RenewLastUpdate(uint256 itemId, uint256 newLastUpdate);

    constructor() ERC721("Herofi Item", "HEROITEMM") {

    }

    function _mint(address to, uint256 itemId) internal override(ERC721) {
        super._mint(to, itemId);
        
        _incrementItemId();
    }

    function mintItem(address to, uint8 _star, uint256 _itemType) external onlyMinter {
        uint256 nextItemId = _getNextItemId();
        _mint(to, nextItemId);
        items[nextItemId] = Item({
            star: _star,
            itemType: _itemType,
            bornAt: block.timestamp,
            lastUpdate: block.timestamp
        });
        emit NewItem(nextItemId, _star, _itemType, block.timestamp, block.timestamp);
    }

    function renewLastUpdate(uint256 _itemId) external onlyUpdater {
        Item memory item = items[_itemId];
        item.lastUpdate = block.timestamp;
        emit RenewLastUpdate(_itemId, block.timestamp);
    }

    function addMinter(address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function addUpdater(address _updater) external onlyOwner {
        updaters[_updater] = true;
    }

    function removeUpdater(address _updater) external onlyOwner {
        updaters[_updater] = false;
    }

    function latestItemId() external view returns (uint256) {
        return _latestItemId;
    }

    function _getNextItemId() private view returns (uint256) {
        return _latestItemId.add(1);
    }
    
    function _incrementItemId() private {
        _latestItemId++;
    }

    function addTypes(uint8 _star, uint256[] memory _types) external onlyOwner {
        require(_star >= 1 && _star <= 6, "require: star 1 - 6");
        starToTypes[_star] = _types;
    }

    function getItemTypes(uint8 _star) external view returns (uint256[] memory) {
        return starToTypes[_star];
    }

    function getItem(uint256 _itemId) public view returns (Item memory) {
        return items[_itemId];
    }
}