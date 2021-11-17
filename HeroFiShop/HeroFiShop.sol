pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPayRofi {
    function payRofi(address _sender, uint256 _amount) external;
}

contract HeroFiShop is Ownable, Pausable {
    IPayRofi public payRofi;
    IPayRofi public payLockedRofi;

    struct Pack {
        string description;
        uint256 price;
        bool isEnable;
    }

    mapping(uint256 => Pack) public packs;

    uint256 public currentPackId;

    event BuyPack(uint256 indexed packId, address indexed buyer, uint256 buyAt);

    event DisablePack(uint256 indexed packId);
    event EnablePack(uint256 indexed packId);

    constructor (address _payRofi, address _payLockedRofi){
        payRofi = IPayRofi(_payRofi);
        payLockedRofi = IPayRofi(_payLockedRofi);
    }

    function addPack(uint256 _price, string memory _description) public onlyOwner {
        currentPackId++;
        packs[currentPackId] = Pack({
        price : _price,
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

    function setPayRofi(address _payRofi) public onlyOwner {
        payRofi = IPayRofi(_payRofi);
    }

    function setPayLockedRofi(address _payLockedRofi) public onlyOwner {
        payLockedRofi = IPayRofi(_payLockedRofi);
    }

    function buyPack(uint256 _packId) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        payRofi.payRofi(_msgSender(), pack.price);
        emit BuyPack(_packId, _msgSender(), block.timestamp);
    }

    function buyPackWithLocked(uint256 _packId) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        payLockedRofi.payRofi(_msgSender(), pack.price);
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
