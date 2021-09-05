// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../interfaces/IRandom.sol";

interface IRandomRequester {
    function submitRandomness(uint _tokenId, uint _randomness) external;
}

interface IERC20 {
    function allowance(address owner, address spender) external view returns (uint);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
}

library LHelper {
    IWETH constant internal weth = IWETH(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c));
    bytes4 private constant SWAP_SELECTOR = 
        bytes4(keccak256(bytes('swapExactTokensForTokens(uint256,uint256,address[],address,uint256)')));
    bytes4 private constant WBNB_DEPOSIT_SELECTOR = 
        bytes4(keccak256(bytes('deposit()')));
    bytes4 private constant TRANSFER_SELECTOR = 
        bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes4 private constant PEG_SWAP_SELECTOR = 
        bytes4(keccak256(bytes('swap(uint256,address,address)')));

    function toWbnb()
        internal
        returns(bool success)
    {
        uint amount = address(this).balance;
        (success, ) = address(weth).call{value: amount}((abi.encodeWithSelector(
            WBNB_DEPOSIT_SELECTOR
        )));  
    }

    function thisTokenBalance(
        address token_
    )
        internal
        view
        returns(uint)
    {
        return IERC20(token_).balanceOf(address(this));
    }

    function thisBnbBalance()
        internal
        view
        returns(uint)
    {
        return address(this).balance + thisTokenBalance(address(weth));
    }

    function approve(
        address token_,
        address to_
    )
        internal
    {
        if (IERC20(token_).allowance(address(this), to_) == 0) {
            IERC20(token_).approve(to_, ~uint256(0));
        }
    }
    
    function pegSwap(
        address router_,
        address fromCurrency_,
        address toCurrency_,
        uint256 amount_
    )
        internal
        returns(bool success)
    {
        approve(fromCurrency_, router_);

        (success, ) = router_.call((abi.encodeWithSelector(
            PEG_SWAP_SELECTOR,
            amount_,
            fromCurrency_,
            toCurrency_
        )));
    }

    function swap(
        address router_,
        address fromCurrency_,
        address toCurrency_,
        uint amount_,
        address to_
    )
        internal
        returns(bool success)
    {
        address[] memory path = new address[](2);
        path[0] = fromCurrency_;
        path[1] = toCurrency_;

        approve(fromCurrency_, router_);

        (success, ) = router_.call((abi.encodeWithSelector(
            SWAP_SELECTOR,
            amount_,
            0,
            path,
            to_,
            block.timestamp
        )));
    }
    
    function toBnb()
        internal
        returns(bool success)
    {
        uint amount = weth.balanceOf(address(this));
        weth.withdraw(amount);
        (success, ) = address(weth).call((abi.encodeWithSelector(
            WBNB_DEPOSIT_SELECTOR,
            amount
        )));  
    }
    
    function transferToken(
        address token_,
        address to_,
        uint amount_
    )
        internal
        returns(bool success)
    {
        (success, ) = token_.call((abi.encodeWithSelector(
            TRANSFER_SELECTOR,
            to_,
            amount_
        )));   
    }

    function transferBnb(
        address to_,
        uint amount_
    )
        internal
        returns(bool success)
    {
        toBnb();
        (success,) = to_.call{value:amount_}(new bytes(0));
        toWbnb();
    }
}

contract RandomFee {
    event SetBnbFee(
        uint amount
    );

    address private _linkAddress;
    address private _peggedLinkAddress;

    uint public _bnbFee;
    uint private _lastWbnbBalance;

    constructor(
        address peggedLinkAdress_,
        address linkAddress_
    )
    {
        _peggedLinkAddress = peggedLinkAdress_;
        _linkAddress = linkAddress_;
    }

    function _setBnbFee(
        uint bnbFee_
    )
        internal
    {
        _bnbFee = bnbFee_;
        emit SetBnbFee(bnbFee_);
    }

    function _updateWbnbBalance()
        internal
        returns(uint added)
    {
        uint currentWbnbBalance = LHelper.thisBnbBalance();
        if (currentWbnbBalance > _lastWbnbBalance) {
            added = currentWbnbBalance - _lastWbnbBalance;
        } else {
            added = 0;
        }
        _lastWbnbBalance = currentWbnbBalance;
        return added;
    }

    function _takeFee()
        internal
        returns(uint)
    {
        uint added = _updateWbnbBalance();
        require(added >= _bnbFee, "RandomFee: not enough for fee");
    }

    function buyLink()
        public
    {
        LHelper.toWbnb();
        LHelper.swap(
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E),
            address(LHelper.weth),
            _peggedLinkAddress,
            LHelper.thisBnbBalance(),
            address(this)
        );
        _updateWbnbBalance();
        LHelper.pegSwap(
            address(0x1FCc3B22955e76Ca48bF025f1A6993685975Bb9e),
            _peggedLinkAddress,
            _linkAddress,
            LHelper.thisTokenBalance(_peggedLinkAddress)
        );
    }
}

contract Random is VRFConsumerBase, IRandom, RandomFee {
    using SafeMath for uint256;
    
    uint256 private constant IN_PROGRESS = 42;

    bytes32 public keyHash;
    
    uint256 public fee;
    
    mapping(bytes32 => uint256) tokens;
    
    mapping(uint256 => uint256) results;
    
    event RandomNumberGenerated(uint256 tokenId);
    
    IRandomRequester private _randomRequester;
    
    constructor()
        RandomFee(
            address(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD), 
            address(0x404460C6A5EdE2D891e8297795264fDe62ADBB75)
        )
        VRFConsumerBase(
            0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31,
            0x404460C6A5EdE2D891e8297795264fDe62ADBB75
        ) public
    {
        keyHash = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c;
        fee = 0.2 * 10 ** 18;
        _randomRequester = IRandomRequester(msg.sender);
    }
    
    receive() external payable {
    }
    
    function requestRandomNumber(uint256 tokenId) external override {
        _takeFee();
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        tokens[requestId] = tokenId;
        results[tokenId] = IN_PROGRESS; 
    }
    
    function setBnbFee(uint bnbFee_) external override {
        require(msg.sender == address(_randomRequester), "Only NFT contract call");
        _setBnbFee(bnbFee_);
    }
    
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = tokens[requestId];
        results[tokenId] = randomness;
        emit RandomNumberGenerated(tokenId);
        _randomRequester.submitRandomness(tokenId, randomness);
    }
    
    function getResultByTokenId(uint256 tokenId) external view override returns (uint256) {
        return results[tokenId];
    }
    
    function withdrawBnb() public {
        LHelper.transferBnb(tx.origin, 0);
    }

    function withdrawToken(address token_) public {
        LHelper.transferToken(token_, tx.origin, 0);
    }
}