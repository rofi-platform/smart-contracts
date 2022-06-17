//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHero {
	struct Hero {
        uint8 star;
        uint8 rarity;
        uint8 plantClass;
        uint256 plantId;
        uint256 bornAt;
    }
}