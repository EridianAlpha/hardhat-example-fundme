// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../FundMe.sol";

/**
 * This contract implements a reentrancy attack on the fundMe.refund() function.
 * It will attempt to call refund() multiple times to drain the contract.
 * This particular attack does not work as the s_addressToAmountFunded mapping
 * is reset to 0 in fundMe.refund() before the value is sent, so this function does not
 * require the nonReentrant modifier from openzeppelin.
 */

contract ReEntrancyAttack {
    FundMe public fundMe;

    constructor(address payable _fundMeAddress) {
        fundMe = FundMe(_fundMeAddress);
    }

    receive() external payable {
        if (address(fundMe).balance >= 1 ether) {
            fundMe.refund();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        fundMe.fund{ value: 1 ether }();
        fundMe.refund();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
