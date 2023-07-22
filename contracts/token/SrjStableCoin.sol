// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SrjStableCoin is ERC20Burnable, Ownable {
    error SrjStableCoin__NotEnoughBalance();
    error SrjStableCoin__BurnAmountExceedsBalance();
    error SrjStableCoin__MustBeMoreThanZero();
    error SrjStableCoin__NotZeroAddress();

    constructor() ERC20("SRJ Stable Coin", "SSC") {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance <= 0) {
            revert SrjStableCoin__NotEnoughBalance();
        }

        if (_amount > balance) {
            revert SrjStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert SrjStableCoin__NotZeroAddress();
        }

        if (_amount <= 0) {
            revert SrjStableCoin__MustBeMoreThanZero();
        }

        _mint(_to, _amount);

        return true;
    }
}
