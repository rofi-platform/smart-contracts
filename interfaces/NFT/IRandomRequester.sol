// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IRandomRequester {
    function submitRandomness(
        uint _tokenId,
        uint _randomness
    )
        external;

    function random()
        external
        view
        returns(address);

    function owner()
        external
        view
        returns(address);
}