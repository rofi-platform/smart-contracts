// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./modules/NFT/Random-Test.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IHero {
	struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 plantClass;
        uint256 plantId;
        uint256 bornAt;
    }
}

interface INFT {
    function latestTokenId() external view returns(uint);

    function getTotalClass() external view returns (uint8);

    function getPlanIds(uint8 _plantClass, uint8 _rarity) external view returns (uint256[] memory);
}

interface ICNFT {
    function mint(address _to, uint8 _star, uint8 _rarity, uint8 _plantClass, uint256 _plantId) external;

    function getNft() external view returns (address);
}

contract BoxNFT is Ownable, ERC721 {
    using SafeMath for uint256;

    ICNFT public cnft;
    Random public random;

    struct Box {
        uint8 boxType;
        uint256 createdAt;
    }

    struct BoxType {
        uint256 price;
        uint8 star;
        uint8[] percents;
        uint256 stock;
        uint256 total;
        address paymentToken;
        bool isAvailable;
        bool useChainlink;
    }

    mapping (uint256 => Box) boxes;

    mapping (uint8 => BoxType) boxTypes;

    uint nonce = 0;

    address public receiver;

    uint256 private _latestTokenId;

    uint256 private _latestRequestId;

    mapping (uint256 => uint8) requestBoxTypeId;

    mapping (uint256 => uint256) requestTimestamp;

    mapping (uint256 => address) requestUser;

    mapping (uint8 => uint256) records;

    modifier onlyRandom {
        require(msg.sender == address(random), "require Random");
        _;
    }

    event BoxMint(uint256 indexed tokenId, address user, uint8 boxType, uint256 timestamp);

    event BoxOpen(address indexed user, uint8 boxId, uint256 heroId, uint256 timestamp);

    constructor(address _cnft, address _receiver) ERC721("PE BOX", "PEBOX") {
        cnft = ICNFT(_cnft);
        receiver = _receiver;
        random = new Random();
    }

    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);
        _incrementTokenId();
    }

    function _getNextTokenId() private view returns (uint256) {
        return _latestTokenId.add(1);
    }
    
    function _incrementTokenId() private {
        _latestTokenId++;
    }

    function mint(address _to, uint8 _boxType, uint8 _amount) external {
        require(_amount >= 1, "require: at least 1");
        BoxType storage boxType = boxTypes[_boxType];
        require(boxType.isAvailable == true, "require: not available");
        require(boxType.stock > 0, "required: out of stock");
        IERC20(boxType.paymentToken).transferFrom(_msgSender(), receiver, boxType.price.mul(_amount));
        uint8 time = 0;
        while (time < _amount) {
            uint256 nextTokenId = _getNextTokenId();
            _mint(_to, nextTokenId);
            
            boxes[nextTokenId] = Box({
                boxType: _boxType,
                createdAt: block.timestamp
            });
            emit BoxMint(nextTokenId, _to, _boxType, block.timestamp);
            time++;
        }
        boxType.stock = boxType.stock.sub(_amount);
    }

    function openBox(uint256[] memory _boxIds) external {
        for (uint256 i = 0; i < _boxIds.length; i++) {
            uint256 boxId = _boxIds[i];
            require(ERC721(this).ownerOf(boxId) == _msgSender(), "require: not owner");
            Box memory box = boxes[boxId];
            BoxType memory boxType = boxTypes[box.boxType];
            require(boxType.isAvailable == true, "require: not available");
            ERC721(this).transferFrom(_msgSender(), address(0x000000000000000000000000000000000000dEaD), boxId);
            if (boxType.useChainlink) {
                requestRandomNumber(_msgSender(), box.boxType, block.timestamp);
            } else {
                _openBox(_msgSender(), box.boxType, 0, false, block.timestamp);
            }
        }
    }

    function _openBox(address _user, uint8 _boxTypeId, uint256 _randomNumber, bool _useChainlink, uint256 _timestamp) internal {
        BoxType memory boxType = boxTypes[_boxTypeId];
        if (_useChainlink == false) {
            _randomNumber = getRandomNumber();
        }
        uint8 rarity = getHeroRarity(boxType.percents, _randomNumber.mod(100).add(1));
        INFT nft = INFT(cnft.getNft());
        uint8 plantClass = uint8(_randomNumber.mod(nft.getTotalClass()).add(1));
        uint256[] memory planIds = nft.getPlanIds(plantClass, rarity);
        uint256 planId = planIds[_randomNumber.mod(planIds.length)];
        cnft.mint(_user, boxType.star, rarity, plantClass, planId);
        emit BoxOpen(_user, _boxTypeId, nft.latestTokenId(), _timestamp);
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

    function requestRandomNumber(address _user, uint8 _boxTypeId, uint256 _timestamp) internal {
        uint256 requestId = getNextRequestId();
        requestUser[requestId] = _user;
        requestBoxTypeId[requestId] = _boxTypeId;
        requestTimestamp[requestId] = _timestamp;
        incrementRequestId();
        random.requestRandomNumber(requestId);
    }

    function submitRandomness(uint _requestId, uint _randomness) external onlyRandom {
        address user = requestUser[_requestId];
        uint8 boxTypeId = requestBoxTypeId[_requestId];
        uint256 timestamp = requestTimestamp[_requestId];
        _openBox(user, boxTypeId, _randomness, true, timestamp);
    }

    function updateBox(uint8 _id, uint256 _price, uint8 _star, uint8[] memory _percents, uint256 _stock, uint256 _total, address _paymentToken, bool _useChainlink) external onlyOwner {
        uint256 length = _percents.length;
        require(length == 5, "require: need 5");
        require(_price > 0, "require: box price must > 0");
        require(_paymentToken != address(0), "payment token must != zero address");
        boxTypes[_id] = BoxType({
            price: _price,
            star: _star,
            percents: _percents,
            stock: _stock,
            total: _total,
            paymentToken: _paymentToken,
            useChainlink: _useChainlink,
            isAvailable: true
        });
    }

    function updateBoxTypeAvailable(uint8 _id, bool _available) external onlyOwner {
        BoxType memory boxType = boxTypes[_id];
        boxType.isAvailable = _available;
    }

    function getBoxType(uint8 _id) public view returns (BoxType memory) {
        return boxTypes[_id];
    }

    function getTotalBoxCanOpen(uint8 _boxTypeId) public view returns (uint256) {
        BoxType memory boxType = boxTypes[_boxTypeId];
        return boxType.total;
    }

    function getRemainingBoxAmount(uint8 _boxTypeId) public view returns (uint256) {
        BoxType memory boxType = boxTypes[_boxTypeId];
        return boxType.stock;
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

    function updateCnft(address _cnft) external onlyOwner {
        cnft = ICNFT(_cnft);
    }

    function setBnbFee(uint256 _bnbFee) external onlyOwner {
        random.setBnbFee(_bnbFee);
    }

    function getBox(uint256 _tokenId) public view returns (Box memory) {
        return boxes[_tokenId];
    }
}