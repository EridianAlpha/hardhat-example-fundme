// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../FundMe.sol";

contract TestHelper {
    address priceFeedAddress;
    FundMe fundMeContract;

    constructor() {
        fundMeContract = new FundMe(priceFeedAddress);
    }

    function fundMeWithdraw() public payable {
        fundMeContract.withdraw();
    }
}
