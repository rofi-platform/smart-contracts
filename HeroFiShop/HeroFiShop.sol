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

    struct Pack {
        uint256 goldAmount;
        uint256 price;
        uint16 ticketAmount;
        bool isEnable;
    }

    mapping(uint8 => Pack) public packs;

    uint8 public currentPackId;

    event BuyPack(uint8 indexed packId, address indexed buyer, uint256 buyAt);

    event DisablePack(uint8 indexed packId);
    event EnablePack(uint8 indexed packId);

    constructor (address _payRofi){
        payRofi = IPayRofi(_payRofi);
    }

    function addPack(uint256 _goldAmount, uint16 _ticketAmount, uint256 _price) public onlyOwner {
        currentPackId++;
        packs[currentPackId] = Pack({
        goldAmount : _goldAmount,
        price : _price,
        ticketAmount : _ticketAmount,
        isEnable: true
        });
    }

    function disablePack(uint8 _packId) public onlyOwner {
        Pack storage pack = packs[_packId];
        pack.isEnable = false;
        emit DisablePack(_packId);
    }

    function enablePack(uint8 _packId) public onlyOwner {
        Pack storage pack = packs[_packId];
        pack.isEnable = true;
        emit EnablePack(_packId);
    }

    function setPayRofi(address _payRofi) public onlyOwner {
        payRofi = IPayRofi(_payRofi);
    }

    function buyPack(uint8 _packId) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        payRofi.payRofi(_msgSender(), pack.price);
        emit BuyPack(_packId, _msgSender(), block.timestamp);
    }

    function getPack(uint8 _packId) public view returns (Pack memory) {
        return packs[_packId];
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
