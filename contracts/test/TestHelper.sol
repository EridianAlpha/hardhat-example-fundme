// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "../FundMe.sol";

/**
 * This contract is used to test the .call failing in FundMe.sol
 * Test found in FundMe.test.js "Withdraw .call failure throws error"
 *
 * The reason this contract allows the .call to fail is because it doesn't have a receive() function
 * but I still need to send funds to allow it to pass the "zero balance fails" tests
 * so there is a specific function for sending those initial funds
 */
contract TestHelper {
    address priceFeedAddress;
    FundMe fundMeContract;
    address fundMeContractAddress;

    constructor() {
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
