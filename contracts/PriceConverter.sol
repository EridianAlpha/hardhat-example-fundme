// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// This is a library and not an abstract as all of the functions are fully implemented
library PriceConverter {
    // Must be internal as it is a library function
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        // (
        //     uint80 roundID,
        //     int256 price,
        //     uint startedAt,
        //     uint timeStamp,
        //     uint80 answeredInRound
        // )
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price * 10000000000); // ETH/USD rate in 18 digit
    }

    function getConversionRate(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        uint256 ethPrice = getPrice(priceFeed);
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / (10 ** 18);
        return ethAmountInUsd; // ETH/USD conversion rate, after adjusting the extra 0s.
    }
}
