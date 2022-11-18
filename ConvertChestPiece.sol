// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ChestPieceInfo {
    struct Info {
        address owner;
        uint8 chestType;
        uint256 createdAt;
    }
}

interface ERC721 {
	function ownerOf(uint256 tokenId) external view returns (address owner);

	function transferFrom(address from, address to, uint256 tokenId) external;
}

interface ChestPiece is ERC721, ChestPieceInfo {
    function getChestPiece(uint256 _tokenId) external view returns (Info memory);
}

interface Chest {
    function mint(address _to, uint8 _chestType, uint8 _amount) external;
}

interface Token {
    function approve(address _spender, uint256 _value) external returns (bool success);
}

contract ConvertChestPiece is Ownable, ChestPieceInfo {
    Chest public chest;

    ChestPiece public chestPiece;

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    mapping(uint8 => uint8) public chestType;

    event ConvertSuccess(uint256[] _chestPieceIds);

    constructor(address _chest, address _chestPiece) {
        chest = Chest(_chest);
        chestPiece = ChestPiece(_chestPiece);
    }

    function convert(uint256[] memory _chestPieceIds) external {
        address user = _msgSender();
        uint256 length = _chestPieceIds.length;
        require(length == 10, "require: must have 10 chest pieces");
        uint8 requiredChestPieceType = chestPiece.getChestPiece(_chestPieceIds[0]).chestType;
		for (uint256 i = 0; i < length; i++) {
			Info memory info = chestPiece.getChestPiece(_chestPieceIds[i]);
            require(chestPiece.ownerOf(_chestPieceIds[i]) == user, "require: must be owner of chest piece");
			require(info.chestType == requiredChestPieceType, "require: must same chest type");
		}
        for (uint256 i = 0; i < length; i++) {
            chestPiece.transferFrom(user, deadAddress, _chestPieceIds[i]);
        }
        chest.mint(user, chestType[requiredChestPieceType], 1);
        emit ConvertSuccess(_chestPieceIds);
    }

    function setChestType(uint8 _chestPieceType, uint8 _chestType) external onlyOwner {
        chestType[_chestPieceType] = _chestType;
    }

    function setChest(address _chest) external onlyOwner {
        chest = Chest(_chest);
    }

    function setChestPiece(address _chestPiece) external onlyOwner {
        chestPiece = ChestPiece(_chestPiece);
    }

    function approve(address _token, address _spender, uint256 _amount) external onlyOwner {
        Token(_token).approve(_spender, _amount);
    }
}