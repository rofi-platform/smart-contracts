//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IHero {
	struct Hero {
        uint8 star;
        uint8 heroType;
        bytes32 dna;
        bool isGenesis;
        uint256 bornAt;
    }
}