// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../FundMe.sol";

/**
 * This contract is used to test the .call failing in FundMe.sol
 * The test is found in FundMe.test.js:
 * - "Withdraw .call failure throws error"
 * - "Refund .call failure throws error"
 *
 * The reason this contract makes the .call to fail is because it doesn't have a receive() function
 * so the withdrawn and refunded ETH can't be accepted
 * but I still need to send funds to allow it to pass the "zero balance fails" tests
 * so there is a specific payable function for sending those initial funds initialFunding()
 */
contract TestHelper {
    FundMe fundMeContract;

    constructor(address priceFeedAddress) {
        fundMeContract = new FundMe(priceFeedAddress);
    }

    function initialFunding() public payable {}

    function fundMeFund(uint256 sendValue) public payable {
        // Send funds directly to the fundMeContract address
        // which get picked up by the receive function which calls fund()
        // creating a funder deposit for this contract
        (bool callSuccess, ) = address(fundMeContract).call{ value: sendValue }(
            ""
        );
        callSuccess;
    }

    function fundMeWithdraw() public payable {
        fundMeContract.withdraw();
    }

    function fundMeRefund() public payable {
        fundMeContract.refund();
    }
}
