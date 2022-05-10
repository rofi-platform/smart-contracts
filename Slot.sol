// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Slot is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct Record {
        address user;
        uint256 numberSlot;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 private _lastRecordId;

    mapping (uint256 => Record) public records;

    mapping (address => uint256) public slotByUser;

    mapping (address => EnumerableSet.UintSet) private slots;

    IERC20 public token;

    uint256 public perSlot;

    uint256 public totalSlot;

    uint256 public availableSlot;

    address public receiver;

    event BuySlot(address indexed user, uint256 recordId);

    constructor(address _token, uint256 _totalSlot, uint256 _perSlot, address _receiver) {
        token = IERC20(_token);
        totalSlot = _totalSlot;
        availableSlot = _totalSlot;
        perSlot = _perSlot;
        receiver = _receiver;
    }

    function buySlot(uint256 _numberSlot) external {
        require(availableSlot > 0, "out of slot");
        uint256 total = _numberSlot.mul(perSlot);
        token.transferFrom(msg.sender, receiver, total);
        availableSlot = availableSlot.sub(1);
        uint256 currentSlotNumber = slotByUser[msg.sender];
        slotByUser[msg.sender] = currentSlotNumber.add(_numberSlot);
        uint256 nextRecordId = _getNextRecordId();
		_incrementRecordId();
        records[nextRecordId] = Record({
            user: msg.sender,
            numberSlot: _numberSlot,
            amount: total,
            timestamp: block.timestamp
        });
        slots[msg.sender].add(nextRecordId);
        emit BuySlot(msg.sender, nextRecordId);
    }

    function getAvailableSlot() public view returns (uint256) {
        return availableSlot;
    }

    function getRecord(uint256 _recordId) public view returns (Record memory) {
        return records[_recordId];
    }

    function getRecordIds() external view returns (uint256[] memory) {
        uint256 length = slots[msg.sender].length();
        uint256[] memory recordIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            recordIds[i] = slots[msg.sender].at(i);
        }
        return recordIds;
    }

    function getSlotByUser(address _user) public view returns (uint256) {
        return slotByUser[_user];
    }

    function updateToken(address _token) external onlyOwner {
        token = IERC20(_token);
    }

    function updatePerSlot(uint256 _perSlot) external onlyOwner {
        perSlot = _perSlot;
    }

    function updateReceiver(address _receiver) external onlyOwner {
        receiver = _receiver;
    }

    function _getNextRecordId() private view returns (uint256) {
        return _lastRecordId.add(1);
    }
    
    function _incrementRecordId() private {
        _lastRecordId++;
    }
    
    function latestRecordId() external view returns(uint) {
        return _lastRecordId;
    }
}