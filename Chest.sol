// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./modules/NFT/Random-Chest.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Item {
    function latestItemId() external returns (uint256);

    function mintItem(address _to, uint8 _star, uint256 _itemType) external;

    function getItemTypes(uint8 _star) external returns (uint256[] memory);
}

contract Chest is Ownable {
    using SafeMath for uint256;

    Item public item;
    Random public random;

    struct ChestType {
        uint256 price;
        uint8[] percents;
        address paymentToken;
        bool isAvailable;
        bool useChainlink;
    }

    mapping (uint8 => ChestType) chests;

    uint nonce = 0;

    address public receiver;

    uint256 private _latestRequestId;

    mapping (uint256 => uint8) requestChestId;

    mapping (uint256 => uint8) requestChestAmount;

    mapping (uint256 => uint256) requestTimestamp;

    mapping (uint256 => address) requestUser;

    modifier onlyRandom {
        require(msg.sender == address(random), "require Random.");
        _;
    }

    event ChestOpen(address indexed user, uint8 chestId, uint256[] itemIds, uint256 timestamp);

    constructor(address _item, address _receiver) {
        item = Item(_item);
        receiver = _receiver;
        random = new Random();
    }

    function openChest(uint8 _id, uint8 _amount) external {
        require(_amount >= 1, "require: at least 1");
        ChestType memory chest = chests[_id];
        require(chest.isAvailable == true, "require: not available");
        IERC20(chest.paymentToken).transferFrom(_msgSender(), receiver, chest.price.mul(_amount));
        if (chest.useChainlink) {
            requestRandomNumber(_msgSender(), _id, _amount, block.timestamp);
        } else {
            _openChest(_msgSender(), _id, 0, _amount, false, block.timestamp);
        }
    }

    function _openChest(address _user, uint8 _id, uint8 _randomNumber, uint8 _amount, bool _useChainlink, uint256 _timestamp) internal {
        ChestType memory chest = chests[_id];
        uint8[] memory percents = chest.percents;
        uint8 time = 0;
        uint256[] memory itemIds = new uint256[](_amount);
        while (time < _amount) {
            uint8 star;
            if (_useChainlink) {
                _randomNumber = uint8(uint256(keccak256(abi.encode(_randomNumber, time))).mod(100).add(1));
            } else {
                _randomNumber = uint8(getRandomNumber().mod(100).add(1));
            }
            star = getItemStar(percents, _randomNumber);
            uint256[] memory itemTypes = item.getItemTypes(star);
            uint256 totalTypes = itemTypes.length;
            uint256 itemType = itemTypes[uint256(_randomNumber).mod(totalTypes)];
            item.mintItem(_user, star, itemType);
            uint256 newItemId = item.latestItemId();
            itemIds[time] = newItemId;
            time++;
        }
        emit ChestOpen(_user, _id, itemIds, _timestamp);
    }

    function getItemStar(uint8[] memory _percents, uint8 _randomNumber) internal returns (uint8) {
        uint8 star;
        uint256 length = _percents.length;
        for (uint256 i = 0; i < length; i++) {
            uint8 percent = uint8(_percents[i]);
            if (_randomNumber <= percent) {
                star = uint8(i.add(1));
                break;
            }
        }
        return star;
    }

    function getRandomNumber() internal returns (uint256) {
        nonce += 1;
        return uint256(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function requestRandomNumber(address _user, uint8 _id, uint8 _amount, uint256 _timestamp) internal {
        uint256 requestId = getNextRequestId();
        requestUser[requestId] = _user;
        requestChestId[requestId] = _id;
        requestChestAmount[requestId] = _amount;
        requestTimestamp[requestId] = _timestamp;
        incrementRequestId();
        random.requestRandomNumber(requestId);
    }

    function submitRandomness(uint _requestId, uint _randomness) external onlyRandom {
        address user = requestUser[_requestId];
        uint8 chestId = requestChestId[_requestId];
        uint8 amount = requestChestAmount[_requestId];
        uint256 timestamp = requestTimestamp[_requestId];
        _openChest(user, chestId, uint8(_randomness), amount, true, timestamp);
    }

    function updateChest(uint8 _id, uint256 _price, uint8[] memory _percents, address _paymentToken, bool _useChainlink) external onlyOwner {
        uint256 length = _percents.length;
        require(length == 6, "require: need 6");
        require(_price > 0, "require: chest price must > 0");
        require(_paymentToken != address(0), "payment token must != zero address");
        chests[_id] = ChestType({
            price: _price,
            percents: _percents,
            paymentToken: _paymentToken,
            useChainlink: _useChainlink,
            isAvailable: true
        });
    }

    function updateChestAvailable(uint8 _id, bool _available) external onlyOwner {
        ChestType memory chest = chests[_id];
        chest.isAvailable = _available;
    }

    function getChest(uint8 _id) public view returns (ChestType memory) {
        return chests[_id];
    }

    function getNextRequestId() private view returns (uint256) {
        return _latestRequestId.add(1);
    }
    
    function incrementRequestId() private {
        _latestRequestId++;
    }

    function latestRequestId() external view returns (uint256) {
        return _latestRequestId;
    }

    function updateRandom(address payable _newRandom) external onlyOwner {
        random = Random(_newRandom);
    }

    function updateReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }

    function setBnbFee(uint256 _bnbFee) external onlyOwner {
        random.setBnbFee(_bnbFee);
    }
}