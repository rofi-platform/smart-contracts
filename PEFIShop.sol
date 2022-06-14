pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPEFI {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function lockedOf(address account) external view returns (uint256);
}

contract PEFIShop is Ownable, Pausable {
    address public receiverToken;
    IPEFI public immutable pefi;

    struct Pack {
        string description;
        uint256 price;
        bool isEnable;
    }

    mapping(uint256 => Pack) public packs;

    uint256 public currentPackId;

    event BuyPack(uint256 indexed packId, address indexed buyer, uint256 buyAt, uint256 gemAmount);

    event DisablePack(uint256 indexed packId);
    event EnablePack(uint256 indexed packId);

    constructor (address _pefi, address _receiverToken, uint256 _initialCurrentPackId){
        pefi = IPEFI(_pefi);
        receiverToken = _receiverToken;
        currentPackId = _initialCurrentPackId;
    }

    function addPack(uint256 _price, string memory _description) public onlyOwner {
        currentPackId++;
        packs[currentPackId] = Pack({
            price : _price,
            description : _description,
            isEnable : true
        });
    }

    function updatePack(uint256 _packId, uint256 _price, string memory _description) public onlyOwner {
        Pack storage pack = packs[_packId];
        pack.price = _price;
        pack.description = _description;
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

    function setReceiverAddress(address _receiverToken) public onlyOwner {
        receiverToken = _receiverToken;
    }

    function buyPack(uint256 _packId, uint256 _gemAmount) public whenNotPaused {
        Pack storage pack = packs[_packId];
        require(pack.isEnable, "This pack is disabled!");
        pefi.transferFrom(_msgSender(), receiverToken, pack.price);
        emit BuyPack(_packId, _msgSender(), block.timestamp, _gemAmount);
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
