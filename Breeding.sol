// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IHero {
	struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}

interface IERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);

	function transferFrom(address from, address to, uint256 tokenId) external;
	
	function upgrade(uint256 _tokenId, uint8 _star) external;
	
	function spawn(address to, bool _isGenesis, uint8 _star) external;
	
	function latestTokenId() external view returns(uint);
}

interface INFT is IERC721, IHero {
	function getHero(uint256 _tokenId) external view returns (Hero memory);
}

interface ICNFT {
    function spawn(address to_, uint8 star_) external;
}

contract Breeding is IHero, Ownable {
    using SafeMath for uint256;

    INFT private nft;
    
    ICNFT private cnft;

	struct Breed {
		address owner;
		uint256 tokenId1;
		uint256 tokenId2;
		uint8 newHeroStar;
		uint256 breedingPeriod;
		uint256 startAt;
	}

	mapping(uint256 => Breed) internal breeds;

	event Pregnant(address owner, uint256 breedId);

	event GiveBirth(address owner, uint256 tokenId);

	uint256 private _lastBreedId;
    
    constructor(address _nft, address _cnft) {
        nft = INFT(_nft);
        cnft = ICNFT(_cnft);
    }
    
    function startBreed(uint256 _tokenId1, uint256 _tokenId2) public {
        require(nft.ownerOf(_tokenId1) == _msgSender(), "require: owner");
        require(nft.ownerOf(_tokenId2) == _msgSender(), "require: owner");

        Hero memory hero1 = nft.getHero(_tokenId1);
		Hero memory hero2 = nft.getHero(_tokenId2);

		uint8 hero1Sex = getSex(hero1.heroType);
		uint8 hero2Sex = getSex(hero2.heroType);
		require(hero1Sex + hero2Sex == 1, "require: one male and one female");

		nft.transferFrom(_msgSender(), address(this), _tokenId1);
		nft.transferFrom(_msgSender(), address(this), _tokenId2);

		uint8 hero1Star = hero1.star;
		uint8 hero2Star = hero2.star;
		uint8 _newHeroStar = hero1Star < hero2Star ? hero1Star : hero2Star;
		if (_newHeroStar < 3) {
			_newHeroStar = 3;
		}
		
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
		emit Pregnant(_msgSender(), nextBreedId);
    }

	function giveBirth(uint256 _breedId) public {
		Breed storage breed = breeds[_breedId];
		require(breed.owner == _msgSender(), "require: owner");
		require(nft.ownerOf(breed.tokenId1) == address(this), "require: owner");
        require(nft.ownerOf(breed.tokenId2) == address(this), "require: owner");
// 		require(breed.startAt + breed.breedingPeriod >= block.timestamp, "require: not enough breeding time");
		cnft.spawn(_msgSender(), breed.newHeroStar);
		uint256 newTokenId = nft.latestTokenId();
		nft.transferFrom(address(this), _msgSender(), breed.tokenId1);
		nft.transferFrom(address(this), _msgSender(), breed.tokenId2);
		emit GiveBirth(_msgSender(), newTokenId);
	}
	
	function getBreed(uint256 _breedId) public view returns (Breed memory) {
	    return breeds[_breedId];
	}

	function getSex(uint8 _heroType) private view returns (uint8) {
		if (_heroType == 3 || _heroType == 5) {
			return 0;
		}

		return 1;
	}
	
	function getBreedingPeriod(uint256 _bornAt, bool _isGenesis) private view returns (uint256) {
	    uint256 lifeTime = uint256(block.timestamp - _bornAt);
	    uint256 breedingPeriod = _isGenesis ? 864000 : Math.min(lifeTime.div(864000).mul(5), 120);
	    return breedingPeriod;
	}
	
	function transferBack(uint256 _tokenId1, uint256 _tokenId2) public {
	    nft.transferFrom(address(this), _msgSender(), _tokenId1);
		nft.transferFrom(address(this), _msgSender(), _tokenId2);
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