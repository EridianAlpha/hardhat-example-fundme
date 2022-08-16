// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./FundMe.sol";

/** @title FundMeMatching
 *  @author EridianAlpha
 *  @notice A template contract showing the implementation of inheritance and override functions
 */
contract FundMeMatching is FundMe {
    // Type declarations
    using PriceConverter for uint256; // Extends uint256 (used from msg.value) to enable direct price conversion

    /**
     * This is how to create a constructor for an inherited contract
     * if the parent already has a constructor that has arguments passed
     * https://docs.soliditylang.org/en/develop/contracts.html#arguments-for-base-constructors
     */
    constructor(address priceFeedAddress) FundMe(priceFeedAddress) {}

    function initialFunding() public payable {}

    function fund() public payable override {
        // Use super. to call overridden functions from the inherited contract
        super.fund();
    }
}
