// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./modules/NFT/Random.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHero {
	struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 class;
        uint256 plantId;
        uint256 bornAt;
    }
}

interface INFT {
    function latestTokenId() external view returns(uint);

    function getTotalClass() external view returns (uint8);

    function getPlanIds(uint8 _class) external view returns (uint256[] memory);
}

interface ICNFT {
    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _class, uint256 _plantId) external;

    function getNft() external view returns (address);
}

contract Box is Ownable {
    using SafeMath for uint256;

    ICNFT public cnft;
    Random public random;

    struct BoxType {
        uint256 price;
        uint8 star;
        uint8[] percents;
        address paymentToken;
        bool isAvailable;
        bool useChainlink;
    }

    mapping (uint8 => BoxType) boxes;

    uint nonce = 0;

    address public receiver;

    uint256 private _latestRequestId;

    mapping (uint256 => uint8) requestBoxId;

    mapping (uint256 => uint8) requestBoxAmount;

    mapping (uint256 => uint256) requestTimestamp;

    mapping (uint256 => address) requestUser;

    modifier onlyRandom {
        require(msg.sender == address(random), "require Random");
        _;
    }

    event BoxOpen(address indexed user, uint8 boxId, uint256[] heroIds, uint256 timestamp);

    constructor(address _cnft, address _receiver) {
        cnft = ICNFT(_cnft);
        receiver = _receiver;
        random = new Random();
    }

    function openBox(uint8 _id, uint8 _amount) external {
        require(_amount >= 1, "require: at least 1");
        BoxType memory box = boxes[_id];
        require(box.isAvailable == true, "require: not available");
        IERC20(box.paymentToken).transferFrom(_msgSender(), receiver, box.price.mul(_amount));
        if (box.useChainlink) {
            requestRandomNumber(_msgSender(), _id, _amount, block.timestamp);
        } else {
            _openBox(_msgSender(), _id, 0, _amount, false, block.timestamp);
        }
    }

    function _openBox(address _user, uint8 _id, uint256 _randomNumber, uint8 _amount, bool _useChainlink, uint256 _timestamp) internal {
        BoxType memory box = boxes[_id];
        uint8 time = 0;
        uint256[] memory heroIds = new uint256[](_amount);
        while (time < _amount) {
            if (_useChainlink) {
                _randomNumber = uint256(keccak256(abi.encode(_randomNumber, time)));
            } else {
                _randomNumber = getRandomNumber();
            }
            uint8 rarity = getHeroRarity(box.percents, _randomNumber.mod(100).add(1));
            INFT nft = INFT(cnft.getNft());
            uint8 class = uint8(_randomNumber.mod(nft.getTotalClass()).add(1));
            uint256[] memory planIds = nft.getPlanIds(class);
            uint256 planId = planIds[_randomNumber.mod(planIds.length)];
            cnft.mint(_user, box.star, rarity, class, planId);
            heroIds[time] = nft.latestTokenId();
            time++;
        }
        emit BoxOpen(_user, _id, heroIds, _timestamp);
    }

    function getHeroRarity(uint8[] memory _percents, uint256 _randomNumber) internal returns (uint8) {
        uint8 rarity;
        uint256 length = _percents.length;
        for (uint256 i = 0; i < length; i++) {
            uint8 percent = uint8(_percents[i]);
            if (_randomNumber <= percent) {
                rarity = uint8(i.add(1));
                break;
            }
        }
        return rarity;
    }

    function getRandomNumber() internal returns (uint256) {
        nonce += 1;
        return uint256(keccak256(abi.encodePacked(nonce, msg.sender, blockhash(block.number - 1))));
    }

    function requestRandomNumber(address _user, uint8 _id, uint8 _amount, uint256 _timestamp) internal {
        uint256 requestId = getNextRequestId();
        requestUser[requestId] = _user;
        requestBoxId[requestId] = _id;
        requestBoxAmount[requestId] = _amount;
        requestTimestamp[requestId] = _timestamp;
        incrementRequestId();
        random.requestRandomNumber(requestId);
    }

    function submitRandomness(uint _requestId, uint _randomness) external onlyRandom {
        address user = requestUser[_requestId];
        uint8 boxId = requestBoxId[_requestId];
        uint8 amount = requestBoxAmount[_requestId];
        uint256 timestamp = requestTimestamp[_requestId];
        _openBox(user, boxId, _randomness, amount, true, timestamp);
    }

    function updateBox(uint8 _id, uint256 _price, uint8 _star, uint8[] memory _percents, address _paymentToken, bool _useChainlink) external onlyOwner {
        uint256 length = _percents.length;
        require(length == 5, "require: need 5");
        require(_price > 0, "require: box price must > 0");
        require(_paymentToken != address(0), "payment token must != zero address");
        boxes[_id] = BoxType({
            price: _price,
            star: _star,
            percents: _percents,
            paymentToken: _paymentToken,
            useChainlink: _useChainlink,
            isAvailable: true
        });
    }

    function updateBoxAvailable(uint8 _id, bool _available) external onlyOwner {
        BoxType memory box = boxes[_id];
        box.isAvailable = _available;
    }

    function getBox(uint8 _id) public view returns (BoxType memory) {
        return boxes[_id];
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