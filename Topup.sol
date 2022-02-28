// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IBEP20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract Bannable {
    mapping(address => bool) private _isBanned;

    event Ban(address indexed user, string reason);
    event Unban(address indexed user, string reason);

    modifier onlyNotBanned(address _user) {
        require(!_isBanned[_user], "Bannable: banned!");
        _;
    }

    modifier onlyBanned(address _user) {
        require(_isBanned[_user], "Bannable: not banned!");
        _;
    }

    function _ban(address _user, string memory _reason) internal onlyNotBanned(_user) {
        _isBanned[_user] = true;
        emit Ban(_user, _reason);
    }

    function _unban(address _user, string memory _reason) internal onlyBanned(_user) {
        _isBanned[_user] = false;
        emit Unban(_user, _reason);
    }

    function isBanned(address _user) public view returns(bool) {
        return _isBanned[_user];
    }
}

contract Topup is Bannable, Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    IBEP20 public token;

    struct Receipt {
        address user;
        uint256 amount;
        uint256 timestamp;
    }

    uint256 private lastReceiptId;

    mapping (uint256 => Receipt) private receipts;

    mapping (address => EnumerableSet.UintSet) private records;

    address public receiver;

    event TopupSuccess(address indexed user, uint256 amount, uint256 receiptId);

    constructor(address _token, address _receiver) {
        token = IBEP20(_token);
        receiver = _receiver;
    }

    function topup(uint256 _amount) public {
        token.transferFrom(msg.sender, receiver, _amount);

        uint256 nextReceiptId = getNextReceiptId();
		incrementReceiptId();

        receipts[nextReceiptId] = Receipt({
            user: msg.sender,
            amount: _amount,
            timestamp: block.timestamp
        });

        records[msg.sender].add(nextReceiptId);

        emit TopupSuccess(msg.sender, _amount, nextReceiptId);
    }

    function getReceipt(uint256 _receiptId) public view returns (Receipt memory) {
        return receipts[_receiptId];
    }

    function getReceiptIds(address _user) public view returns (uint256[] memory) {
        uint256 length = records[_user].length();
        uint256[] memory receiptIds = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            receiptIds[i] = records[_user].at(i);
        }
        return receiptIds;
    }

    function ban(address _user, string memory _reason) public onlyOwner {
        _ban(_user, _reason);
    }

    function unban(address _user, string memory _reason) public onlyOwner {
        _unban(_user, _reason);
    }

    function updateToken(address _token) public onlyOwner {
        token = IBEP20(_token);
    }

    function updateReceiver(address _receiver) public onlyOwner {
        receiver = _receiver;
    }

    function getNextReceiptId() private view returns (uint256) {
        return lastReceiptId.add(1);
    }
    
    function incrementReceiptId() private {
        lastReceiptId++;
    }
    
    function latestReceiptId() external view returns(uint256) {
        return lastReceiptId;
    }
}