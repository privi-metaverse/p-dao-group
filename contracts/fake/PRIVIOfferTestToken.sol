// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PRIVIOfferTestToken is ERC20, Ownable {
    constructor() ERC20("PRIVIOfferTestToken", "PRIVIOfferTest") {
        mint(msg.sender, 10000);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}