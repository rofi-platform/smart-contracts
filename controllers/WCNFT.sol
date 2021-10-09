//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface CNFT {
    function upgrade(uint256 _tokenId, uint8 _star) external;
    
    function transferOwnership(address newOwner) external;
}

contract WCNFT is Ownable {
    CNFT private cnft;
    
    mapping (address => bool) _upgraders;
    
    modifier onlyUpgrader {
        require(_upgraders[msg.sender] || owner() == msg.sender, "require Upgrader");
        _;
    }
    
    constructor(address _cnft) {
        cnft = CNFT(_cnft);
    }
    
    function upgrade(uint256 _tokenId, uint8 _star) external onlyUpgrader {
        cnft.upgrade(_tokenId, _star);
    }
    
    function upgraders(address _address) external view returns (bool) {
        return _upgraders[_address];
    }
    
    function addUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = true;
    }
    
    function removeUpgrader(address _address) external onlyOwner {
        _upgraders[_address] = false;
    }
    
    function transferCNFTOwnership(address newOwner) public onlyOwner {
        cnft.transferOwnership(newOwner);
    }
}