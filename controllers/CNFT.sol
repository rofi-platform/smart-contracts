//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/INFT.sol";
import "../interfaces/IHero.sol";

contract CNFT is Ownable, IHero {
    using SafeMath for uint256;
    
    modifier onlyPaidFee {
        address random = nftContract.random();
        random.call{value: msg.value}(new bytes(0));
        _;
    }

    modifier onlyGenesisActive {
        require(_isGenesisActive, "CNFT: genesis spawn disabled!");
        _;
    }

    IERC20 public paymentToken;
    INFT public nftContract;

    uint256 public eggPrice = 100000*10**18;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    bool private _isGenesisActive = true;

    uint8 private totalHeroTypes = 6;
    
    struct Breed {
		address owner;
		uint256 tokenId1;
		uint256 tokenId2;
		uint8 newHeroStar;
		uint256 breedingPeriod;
		uint256 startAt;
	}

	mapping(uint256 => Breed) internal breeds;

    mapping(uint8 => uint8) internal genders;

	event Pregnant(address owner, uint256 tokenId1, uint256 tokenId2, uint256 breedingPeriod, uint256 breedId);

	event GiveBirth(address owner, uint256 tokenId1, uint256 tokenId2, uint256 tokenId);

	uint256 private _lastBreedId;

    constructor(
        address paymentTokenAddress_,
        address nftContractAddress_
    )
    {
        bytes4 SELECTOR =  bytes4(keccak256(bytes('initController(address)')));
        nftContractAddress_.call((abi.encodeWithSelector(
            SELECTOR,
            address(this)
        )));

        nftContract = INFT(nftContractAddress_);
        paymentToken = IERC20(paymentTokenAddress_);
    }

    function setGenesisActive(
        bool isActive_
    )
        external
        onlyOwner
    {
        _isGenesisActive = isActive_;
    }

    function command(address dest_, uint value_, bytes memory data_) external onlyOwner returns (bool success) {
        (success, ) = address(dest_).call{value: value_}(data_);
    }

    function ban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.ban(tokenId_, reason_);
    }

    function unban(uint tokenId_, string memory reason_) external onlyOwner {
        nftContract.unban(tokenId_, reason_);
    }

    function setBnbFee(uint bnbFee_) external onlyOwner {
        nftContract.setBnbFee(bnbFee_);
    }

    function upgrade(uint256 _tokenId, uint8 _star) external  onlyOwner {
        nftContract.upgrade(_tokenId, _star);
    }

    function genesisSpawn() external payable onlyPaidFee onlyGenesisActive {
        paymentToken.transferFrom(msg.sender, deadAddress, eggPrice);
        bool _isGenesis = true;
        nftContract.spawn(msg.sender, _isGenesis, uint8(0));
    }

    function spawn(address to_, uint8 star_) public payable onlyPaidFee onlyOwner {
        bool _isGenesis = false;
        nftContract.spawn(to_, _isGenesis, star_);
    }

    function getStarFromRandomness(uint256 _randomness) external pure returns(uint8) {
        uint seed = _randomness % 100;
        if (seed < 65) {
            return 3;
        }
        if (seed < 90) {
            return 4;
        }
        if (seed < 98) {
            return 5;
        }
        return 6;
    }

    function getTotalHeroTypes() external view returns (uint8) {
        return totalHeroTypes;
    }

    function setTotalHeroTypes(uint8 _totalHeroTypes) external onlyOwner {
        totalHeroTypes = _totalHeroTypes;
    }

    function isGenesisActive()
        public
        view
        returns(bool isActive)
    {
        isActive = _isGenesisActive;
    }
    
    function startBreed(uint256 _tokenId1, uint256 _tokenId2) external {
        require(nftContract.ownerOf(_tokenId1) == _msgSender(), "not owner");
        require(nftContract.ownerOf(_tokenId2) == _msgSender(), "not owner");

        Hero memory hero1 = nftContract.getHero(_tokenId1);
		Hero memory hero2 = nftContract.getHero(_tokenId2);

		uint8 hero1Sex = genders[hero1.heroType];
		uint8 hero2Sex = genders[hero2.heroType];
		require(hero1Sex + hero2Sex == 1, "need one male & one female");

		nftContract.transferFrom(_msgSender(), address(this), _tokenId1);
		nftContract.transferFrom(_msgSender(), address(this), _tokenId2);

		uint8 hero1Star = hero1.star;
		uint8 hero2Star = hero2.star;
		uint8 _newHeroStar = Math.min(Math.min(hero1Star, hero2Star), 3);
		
		uint256 hero1BreedingPeriod = getBreedingPeriod(hero1.bornAt, hero1.isGenesis);
		uint256 hero2BreedingPeriod = getBreedingPeriod(hero2.bornAt, hero2.isGenesis);
		uint256 _breedingPeriod = Math.max(hero1BreedingPeriod, hero2BreedingPeriod);
		
		uint256 nextBreedId = _getNextBreedId();
		_incrementBreedId();
		breeds[nextBreedId] = Breed({
			owner: _msgSender(),
			tokenId1: _tokenId1,
			tokenId2: _tokenId2,
			newHeroStar: _newHeroStar,
			breedingPeriod: _breedingPeriod,
			startAt: block.timestamp
		});
		emit Pregnant(_msgSender(), tokenId1, tokenId2, breedingPeriod, nextBreedId);
    }

	function giveBirth(uint256 _breedId) external {
		Breed storage breed = breeds[_breedId];
		require(breed.owner == _msgSender(), "not owner");
		require(nftContract.ownerOf(breed.tokenId1) == address(this), "not owner");
        require(nftContract.ownerOf(breed.tokenId2) == address(this), "not owner");
        // Comment on testing
// 		require(breed.startAt + breed.breedingPeriod <= block.timestamp, "not enough breeding time");
		spawn(_msgSender(), breed.newHeroStar);
		uint256 newTokenId = nftContract.latestTokenId();
		nftContract.transferFrom(address(this), _msgSender(), breed.tokenId1);
		nftContract.transferFrom(address(this), _msgSender(), breed.tokenId2);
		emit GiveBirth(_msgSender(), breed.tokenId1, breed.tokenId2, newTokenId);
	}
	
	function getBreed(uint256 _breedId) public view returns (Breed memory) {
	    return breeds[_breedId];
	}
	
	function getBreedingPeriod(uint256 _bornAt, bool _isGenesis) private view returns (uint256) {
	    uint256 lifeTime = uint256(block.timestamp - _bornAt);
	    uint256 breedingPeriod = _isGenesis ? 10 days : Math.min( 10 days + lifeTime.div(10 days).mul(5 days), 120 days);
	    return breedingPeriod;
	}
	
	// Only for test
	function transferBack(uint256 _tokenId1, uint256 _tokenId2) public {
	    nftContract.transferFrom(address(this), _msgSender(), _tokenId1);
		nftContract.transferFrom(address(this), _msgSender(), _tokenId2);
	}
	
	function _getNextBreedId() private view returns (uint256) {
        return _lastBreedId.add(1);
    }
    
    function _incrementBreedId() private {
        _lastBreedId++;
    }
    
    function latestBreedId() external view returns(uint) {
        return _lastBreedId;
    }
}