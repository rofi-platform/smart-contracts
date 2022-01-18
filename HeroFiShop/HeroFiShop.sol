pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IROFI {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract HeroFiShop is Ownable, Pausable {
    address public payRofiUnlocked;
    address public payRofiLocked;
    IROFI public immutable rofi;

    struct Pack {
        string description;
        uint256 unlockPrice;
        uint256 lockPrice;
        bool isEnable;
    }

    mapping(uint256 => Pack) public packs;

    uint256 public currentPackId;

    event BuyPack(uint256 indexed packId, address indexed buyer, uint256 buyAt);

    event DisablePack(uint256 indexed packId);
    event EnablePack(uint256 indexed packId);

    constructor (address _rofi, address _payRofiUnlocked, address _payRofiLocked, uint256 _initialCurrentPackId){
        rofi = IROFI(_rofi);
        payRofiUnlocked = _payRofiUnlocked;
        payRofiLocked = _payRofiLocked;
        currentPackId = _initialCurrentPackId;
    }

    function addPack(uint256 _unlockPrice, uint256 _lockPrice, string memory _description) public onlyOwner {
        currentPackId++;
        packs[currentPackId] = Pack({
        unlockPrice : _unlockPrice,
        lockPrice : _lockPrice,
        description : _description,
        isEnable : true
        });
    }

    function disablePack(uint256 _packId) public onlyOwner {
        Pack storage pack = packs[_packId];
        pack.isEnable = false;
        emit DisablePack(_packId);
    }

    function enablePack(uint256 _packId) public onlyOwner {
        Pack storage pack = packs[_packId];
        pack.isEnable = true;
        emit EnablePack(_packId);
    }

    function setPayRofiUnlocked(address _payRofiUnlocked) public onlyOwner {
        payRofiUnlocked = _payRofiUnlocked;
    }

    function setPayRofiLocked(address _payRofiLocked) public onlyOwner {
        payRofiLocked = _payRofiLocked;
    }

    function buyPackWithUnlockedRofi(uint256 _packId) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        rofi.transferFrom(_msgSender(), payRofiUnlocked, pack.unlockPrice);
        emit BuyPack(_packId, _msgSender(), block.timestamp);
    }

    function buyPackWithLockedRofi(uint256 _packId) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        rofi.transferFrom(_msgSender(), payRofiLocked, pack.lockPrice);
        emit BuyPack(_packId, _msgSender(), block.timestamp);
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() onlyOwner whenNotPaused public {
        _pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() onlyOwner whenPaused public {
        _unpause();
    }
}
