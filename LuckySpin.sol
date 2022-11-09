// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface Chest {
    function mint(address _to, uint8 _chestType, uint8 _amount) external;

    function latestTokenId() external view returns(uint);
}

interface ChestPiece {
    function mint(address _to, uint8 _chestType, uint8 _amount) external;

    function latestTokenId() external view returns(uint);
}

contract LuckySpin is Ownable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    bytes32 public constant GOLD_CHEST = keccak256(abi.encodePacked("Gold Chest"));
    bytes32 public constant PLATINUM_CHEST = keccak256(abi.encodePacked("Platinum Chest"));
    bytes32 public constant HERALD_CHEST = keccak256(abi.encodePacked("Herald Chest"));
    bytes32 public constant RUBY_CHEST = keccak256(abi.encodePacked("Ruby Chest"));
    bytes32 public constant DIAMOND_CHEST = keccak256(abi.encodePacked("Diamond Chest"));
    bytes32 public constant GOLD_PIECE = keccak256(abi.encodePacked("Gold Piece"));
    bytes32 public constant PLATINUM_PIECE = keccak256(abi.encodePacked("Platinum Piece"));
    bytes32 public constant HERALD_PIECE = keccak256(abi.encodePacked("Herald Piece"));
    bytes32 public constant RUBY_PIECE = keccak256(abi.encodePacked("Ruby Piece"));
    bytes32 public constant DIAMOND_PIECE = keccak256(abi.encodePacked("Diamond Piece"));
    bytes32 public constant CHEST_SS = keccak256(abi.encodePacked("Chest SS"));
    bytes32 public constant CHEST_S = keccak256(abi.encodePacked("Chest S"));
    bytes32 public constant CHEST_A = keccak256(abi.encodePacked("Chest A"));
    bytes32 public constant GOLD_TICKET = keccak256(abi.encodePacked("Gold Ticket"));
    bytes32 public constant PLATINUM_TICKET = keccak256(abi.encodePacked("Platinum Ticket"));
    bytes32 public constant HERALD_TICKET  = keccak256(abi.encodePacked("Herald Ticket"));
    bytes32 public constant RUBY_TICKET = keccak256(abi.encodePacked("Ruby Ticket"));
    bytes32 public constant ARENA_TICKET = keccak256(abi.encodePacked("Arena Ticket"));
    bytes32 public constant GEM = keccak256(abi.encodePacked("Gem"));
    bytes32 public constant GOLD = keccak256(abi.encodePacked("Gold"));

    struct Prize {
        string name;
        uint256 limit;
        uint256 percent;
    }

    EnumerableSet.Bytes32Set private prizeList;

    mapping(bytes32 => Prize) public prizeInfo;

    mapping(bytes32 => uint8) public chestType;

    Chest public chest;

    ChestPiece public chestPiece;

    address public validator;

    uint256 public requestExpire = 300;

    uint256[] public accPercentList = [0];

    event SpinSuccess(address indexed user, string name, uint256 chestId, uint256 chestPieceId);

    constructor(address _chest, address _chestPiece) {
        chest = Chest(_chest);
        chestPiece = ChestPiece(_chestPiece);
    }

    function spin(uint256 _nonce, bytes memory _sign) external {
        address user = _msgSender();
        // bool validSign = _validateSign(user, _nonce, _sign);
        // require(validSign, "invalid sign");
        uint256 randomNumber = _random();
        uint256 length = accPercentList.length;
        uint256 seed = randomNumber % accPercentList[length.sub(1)];
        bytes32 prize;
        for (uint256 i = 0; i < length; i++) {
            if (seed < accPercentList[i]) {
                prize = prizeList.at(i);
                break;
            }
        }
        Prize storage info = prizeInfo[prize];
        uint256 remaining = info.limit.sub(1);
        if (remaining == 0) {
            _removePrize(prize);
        } else {
            info.limit = remaining;
        }
        if (prize == GOLD_CHEST || prize == PLATINUM_CHEST || prize == HERALD_CHEST || prize == RUBY_CHEST || prize == DIAMOND_CHEST) {
            _mintChest(prize, user);
            emit SpinSuccess(user, info.name, chest.latestTokenId(), 0);
        } else if (prize == GOLD_PIECE || prize == PLATINUM_PIECE || prize == HERALD_PIECE || prize == RUBY_PIECE || prize == DIAMOND_PIECE) {
            _mintChestPiece(prize, user);
            emit SpinSuccess(user, info.name, 0, chestPiece.latestTokenId());
        } else {
            emit SpinSuccess(user, info.name, 0, 0);
        }
    }

    function addPrize(bytes32 _prize, string memory _name, uint256 _limit, uint256 _percent) external onlyOwner {
        require(_limit >= 1, "invalid limit");
        prizeList.add(_prize);
        prizeInfo[_prize] = Prize({
            name: _name,
            limit: _limit,
            percent: _percent
        });
        _calculateAcc();
    }

    function removePrize(bytes32 _prize) external onlyOwner {
        _removePrize(_prize);
    }

    function _mintChest(bytes32 _prize, address _user) internal {
        chest.mint(_user, chestType[_prize], 1);
    }

    function _mintChestPiece(bytes32 _prize, address _user) internal {
        chest.mint(_user, chestType[_prize], 1);
    }

    function _random() internal view returns (uint256) {
        uint256 blocknumber = block.number;
        uint256 random_gap = uint256(
            keccak256(abi.encodePacked(blockhash(blocknumber - 1), msg.sender))
        ) % 255;
        uint256 random_block = blocknumber - 1 - random_gap;
        bytes32 sha = keccak256(
            abi.encodePacked(
                blockhash(random_block),
                msg.sender,
                block.coinbase,
                block.difficulty
            )
        );
        return uint256(sha);
    }

    function _removePrize(bytes32 _prize) internal {
        prizeList.remove(_prize);
        _calculateAcc();
    }

    function _calculateAcc() internal {
        accPercentList = new uint256[](0);
        uint256 currentCount = 0;
        uint256 length = prizeList.length();
        for (uint256 i = 0; i < length; i++) {
            bytes32 prize = prizeList.at(i);
            Prize memory info = prizeInfo[prize];
            currentCount += info.percent;
            if (i == length - 1) {
                currentCount = 1000;
            }
            accPercentList.push(currentCount);
        }
    }

    function _validateSign(address _user, uint256 _nonce, bytes memory _sign) internal view returns (bool) {
        uint256 _now = block.timestamp;
        require(_now <= _nonce + requestExpire, "request expired");
        bytes32 _hash = keccak256(abi.encodePacked(_user, _nonce));
        _hash = _hash.toEthSignedMessageHash();
        address _signer = _hash.recover(_sign);
        return _signer == validator;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function setExpireTime(uint256 _number) external onlyOwner {
        requestExpire = _number;
    }

    function setChestType(bytes32 _prize, uint8 _chestType) external onlyOwner {
        chestType[_prize] = _chestType;
    }
}

// GOLD_CHEST
// PLATINUM_CHEST
// HERALD_CHEST
// RUBY_CHEST
// DIAMOND_CHEST
// GOLD_PIECE
// PLATINUM_PIECE
// HERALD_PIECE
// RUBY_PIECE
// DIAMOND_PIECE
// CHEST_SS
// CHEST_S
// CHEST_A
// GOLD_TICKET
// PLATINUM_TICKET
// HERALD_TICKET
// RUBY_TICKET
// ARENA_TICKET
// GEM
// GOLD

// Gold Chest
// Platinum Chest
// Herald Chest
// Ruby Chest
// Diamond Chest
// Gold Piece
// Platinum Piece
// Herald Piece
// Ruby Piece
// Diamond Piece
// Chest S
// Chest S
// Chest A
// Gold Ticket
// Platinum Ticket
// Herald Ticket 
// Ruby Ticket
// Arena Ticket
// Gem
// Gold