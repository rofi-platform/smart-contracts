// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface Item {
    function latestItemId() external returns (uint256);

    function mintItem(address _to, uint8 _star, uint256 _itemType) external;

    function getItemTypes(uint8 _star) external returns (uint256[] memory);
}

contract SpecialChestLP is Ownable {
    using SafeMath for uint256;

    Item public item;

    uint nonce = 0;

    uint256 public price;

    uint8[] public percents;

    address public paymentToken;

    address public receiver;

    uint256 private _latestRequestId;

    uint256 public lpPerChest;

    mapping (address => uint256) stakeRecords;

    mapping (address => uint256) chestOpenRecords;

    mapping (uint256 => uint8) requestChestAmount;

    mapping (uint256 => uint256) requestTimestamp;

    mapping (uint256 => address) requestUser;

    event ChestOpen(address indexed user, uint256[] itemIds, uint256 timestamp);

    constructor(uint256 _price, uint8[] memory _percents, address _paymentToken, uint256 _lpPerChest, address _item, address _receiver) {
        price = _price;
        percents = _percents;
        paymentToken = _paymentToken;
        lpPerChest = _lpPerChest;
        item = Item(_item);
        receiver = _receiver;
    }

    function openChest(uint8 _amount) external {
        require(_amount <= getRemainingChestAmount(_msgSender()), "require: exceed allowance");
        require(_amount >= 1, "require: at least 1");
        chestOpenRecords[_msgSender()] += _amount;
        IERC20(paymentToken).transferFrom(_msgSender(), receiver, price.mul(_amount));
        _openChest(_msgSender(), _amount, block.timestamp);
    }

    function _openChest(address _user, uint8 _amount, uint256 _timestamp) internal {
        uint8 time = 0;
        uint256[] memory itemIds = new uint256[](_amount);
        while (time < _amount) {
            uint8 star;
            uint8 _randomNumber = uint8(getRandomNumber().mod(100).add(1));
            star = getItemStar(percents, _randomNumber);
            uint256[] memory itemTypes = item.getItemTypes(star);
            uint256 totalTypes = itemTypes.length;
            uint256 itemType = itemTypes[uint256(_randomNumber).mod(totalTypes)];
            item.mintItem(_user, star, itemType);
            uint256 newItemId = item.latestItemId();
            itemIds[time] = newItemId;
            time++;
        }
        emit ChestOpen(_user, itemIds, _timestamp);
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

    function updateChestPrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    function updateChestPercents(uint8[] memory _percents) external onlyOwner {
        percents = _percents;
    }

    function updatePaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = _paymentToken;
    }

    function updateLpPerChest(uint256 _lpPerChest) external onlyOwner {
        lpPerChest = _lpPerChest;
    }

    function getStakedAmount(address _staker) public view returns (uint256) {
        return stakeRecords[_staker];
    }

    function getChestOpenedAmout(address _staker) public view returns (uint256) {
        return chestOpenRecords[_staker];
    }

    function getTotalChestCanOpen(address _staker) public view returns (uint256) {
        return stakeRecords[_staker].div(lpPerChest);
    }

    function getRemainingChestAmount(address _staker) public view returns (uint256) {
        return getTotalChestCanOpen(_staker).sub(getChestOpenedAmout(_staker));
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

    function updateReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }

    function addStakeRecords(address[] memory _stakers, uint256[] memory _amounts) external onlyOwner {
        uint256 length = _stakers.length;
        require(length == _amounts.length, "params not correct");
        for (uint256 i = 0; i < length; i++) {
            address staker = _stakers[i];
            uint256 amount = uint256(_amounts[i]);
            stakeRecords[staker] = amount;
        }
    }

    function getStakeRecord(address _staker) external view returns (uint256) {
        return stakeRecords[_staker];
    }
}