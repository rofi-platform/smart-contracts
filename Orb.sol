// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OrbNFT is ERC721, Ownable {
    using SafeMath for uint256;

    struct Orb {
        uint8 star;
        uint8 rarity;
        uint8 classType;
        uint256 bornAt;
    }

    uint256 private _latestOrbId;

    mapping (uint256 => Orb) public orbs;

    mapping (address => bool) public minters;

    mapping (address => bool) public updaters;

    modifier onlyMinter() {
        require(minters[msg.sender], "require: only Minter");
        _;
    }

    modifier onlyUpdater() {
        require(updaters[msg.sender], "require: only Updaters");
        _;
    }

    event NewOrb(uint256 orbId, uint8 star, uint8 rarity, uint8 classType, uint256 bornAt);
    event UpdateStar(uint256 orbId, uint8 newStar);
    event UpdateRarity(uint256 orbId, uint8 newRarity);

    constructor() ERC721("Orb", "ORB") {

    }

    function _mint(address to, uint256 orbId) internal override(ERC721) {
        super._mint(to, orbId);
        
        _incrementOrbId();
    }

    function mintOrb(address to, uint8 _star, uint8 _rarity, uint8 _classType) external onlyMinter {
        uint256 nextOrbId = _getNextOrbId();
        _mint(to, nextOrbId);
        orbs[nextOrbId] = Orb({
            star: _star,
            rarity: _rarity,
            classType: _classType,
            bornAt: block.timestamp
        });
        emit NewOrb(nextOrbId, _star, _rarity, _classType, block.timestamp);
    }

    function updateStar(uint256 _orbId, uint8 _newStar) external onlyUpdater {
        Orb storage orb = orbs[_orbId];
        orb.star = _newStar;
        emit UpdateStar(_orbId, _newStar);
    }

    function updateRarity(uint256 _orbId, uint8 _newRarity) external onlyUpdater {
        Orb storage orb = orbs[_orbId];
        orb.rarity = _newRarity;
        emit UpdateRarity(_orbId, _newRarity);
    }

    function addMinter(address _minter) external onlyOwner {
        minters[_minter] = true;
    }

    function removeMinter(address _minter) external onlyOwner {
        minters[_minter] = false;
    }

    function addUpdater(address _updater) external onlyOwner {
        updaters[_updater] = true;
    }

    function removeUpdater(address _updater) external onlyOwner {
        updaters[_updater] = false;
    }

    function latestOrbId() external view returns (uint256) {
        return _latestOrbId;
    }

    function _getNextOrbId() private view returns (uint256) {
        return _latestOrbId.add(1);
    }
    
    function _incrementOrbId() private {
        _latestOrbId++;
    }

    function getOrb(uint256 _orbId) public view returns (Orb memory) {
        return orbs[_orbId];
    }
}