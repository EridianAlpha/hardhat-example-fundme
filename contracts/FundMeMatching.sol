// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./FundMe.sol";

contract FundMeMatching is FundMe {
    // Type declarations
    using PriceConverter for uint256; // Extends uint256 (used from msg.value) to enable direct price conversion

    /**
     * This is how to create a constructor for an inherited contract
     * if the parent already has a contructor that has arguments passed
     * https://docs.soliditylang.org/en/develop/contracts.html#arguments-for-base-constructors
     */
    constructor(address priceFeedAddress) FundMe(priceFeedAddress) {}

    function fund() public payable override {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "You need to spend more ETH!"
        );
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }
}
