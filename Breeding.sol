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
	
	function random() external view returns(address);
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

	mapping(uint8 => uint8) internal genders;

	event Pregnant(address owner, uint256 tokenId1, uint256 tokenId2, uint256 breedingPeriod, uint256 breedId);

	event GiveBirth(address owner, uint256 tokenId1, uint256 tokenId2, uint256 tokenId, uint256 breedId);

	uint256 private _lastBreedId;
	
	modifier onlyPaidFee {
        address random = nft.random();
        random.call{value: msg.value}(new bytes(0));
        _;
    }
    
    constructor(address _nft, address _cnft) {
        nft = INFT(_nft);
        cnft = ICNFT(_cnft);
    }
    
    function startBreed(uint256 _tokenId1, uint256 _tokenId2) external {
        require(nft.ownerOf(_tokenId1) == _msgSender(), "not owner");
        require(nft.ownerOf(_tokenId2) == _msgSender(), "not owner");

        Hero memory hero1 = nft.getHero(_tokenId1);
		Hero memory hero2 = nft.getHero(_tokenId2);

		uint8 hero1Sex = genders[hero1.heroType];
		uint8 hero2Sex = genders[hero2.heroType];
		require(hero1Sex + hero2Sex == 1, "need one male & one female");

		nft.transferFrom(_msgSender(), address(this), _tokenId1);
		nft.transferFrom(_msgSender(), address(this), _tokenId2);

		uint8 _newHeroStar;
		if (hero1.isGenesis && hero2.isGenesis) {
    		_newHeroStar = uint8(Math.min(Math.min(hero1.star, hero2.star), 3));
		} else {
            uint8 hero1Star = (hero1.star > 1) ? hero1.star - 1 : hero1.star;
            uint8 hero2Star = (hero2.star > 1) ? hero2.star - 1 : hero2.star;
		    _newHeroStar = uint8(Math.min(Math.min(hero1Star, hero2Star), 3));
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
		emit Pregnant(_msgSender(), _tokenId1, _tokenId2, _breedingPeriod, nextBreedId);
    }

	function giveBirth(uint256 _breedId) external payable onlyPaidFee {
		Breed storage breed = breeds[_breedId];
		require(breed.owner == _msgSender(), "not owner");
		require(nft.ownerOf(breed.tokenId1) == address(this), "not owner");
        require(nft.ownerOf(breed.tokenId2) == address(this), "not owner");
 		require(breed.startAt + breed.breedingPeriod <= block.timestamp, "not enough breeding time");
		cnft.spawn(_msgSender(), breed.newHeroStar);
		uint256 newTokenId = nft.latestTokenId();
		nft.transferFrom(address(this), _msgSender(), breed.tokenId1);
		nft.transferFrom(address(this), _msgSender(), breed.tokenId2);
		emit GiveBirth(_msgSender(), breed.tokenId1, breed.tokenId2, newTokenId, _breedId);
	}
    
    function updateGender(uint8[] memory _heroTypes, uint8[] memory _genders) external onlyOwner {
        uint256 length = _heroTypes.length;
        require(length == _genders.length, "params not correct");
        for (uint256 i = 0; i < length; i++) {
            uint8 _heroType = uint8(_heroTypes[i]);
            genders[_heroType] = uint8(_genders[i]);
        }
    }
    
    function getGender(uint8 _heroType) public view returns (uint8) {
        return genders[_heroType];
    }
	
	function getBreed(uint256 _breedId) public view returns (Breed memory) {
	    return breeds[_breedId];
	}
	
	function getBreedingPeriod(uint256 _bornAt, bool _isGenesis) private view returns (uint256) {
	    uint256 lifeTime = uint256(block.timestamp - _bornAt);
	    uint256 breedingPeriod = _isGenesis ? 10 days : Math.min( 15 days + lifeTime.div(10 days).mul(5 days), 120 days);
	    return breedingPeriod;
	}
	
	function transferBack(uint256 _tokenId1, uint256 _tokenId2) external onlyOwner {
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