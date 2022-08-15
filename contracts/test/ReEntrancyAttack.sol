// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../FundMe.sol";

/**
 * This contract implements a reentrancy attack on the fundMe.refund() function.
 * It will attempt to call refund() multiple times to drain the contract.
 * This particular attack does not work as the s_addressToAmountFunded mapping
 * is reset to 0 in fundMe.refund() before the value is sent.
 */

contract ReEntrancyAttack {
    FundMe public fundMe;

    constructor(address payable _fundMeAddress) {
        fundMe = FundMe(_fundMeAddress);
    }

    receive() external payable {
        fundMe.refund();
    }

    function attack() external payable {
        fundMe.fund{ value: 1 ether }();
        fundMe.refund();
    }
}
