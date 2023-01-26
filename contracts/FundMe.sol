// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// Imports
// import "hardhat/console.sol"; // Used for console logging during development // console.log("HERE1");
import "./PriceConverter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Error codes
error FundMe__RefundFailed();
error FundMe__RefundNoFunds();
error FundMe__IndexNotFound();
error FundMe__WithdrawFailed();
error FundMe__WithdrawNoFunds();
error FundMe__NotEnoughEthSent();
error FundMe__WithdrawSelfDestructFailed();

/** @title FundMe
 *  @author EridianAlpha
 *  @notice A template contract for funding and withdrawals.
 *  @dev Chainlink is used to implement price feeds.
 */
contract FundMe is Ownable, ReentrancyGuard {
    // Type declarations
    using PriceConverter for uint256; // Extends uint256 (used from msg.value) to enable direct price conversion

    // State variables
    address[] internal s_funders;
    address internal immutable i_creator; // Set in constructor
    AggregatorV3Interface internal immutable s_priceFeed; // Set in constructor
    mapping(address => uint256) internal s_addressToAmountFunded;
    uint256 public constant MINIMUM_USD = 100 * 10 ** 18; // Constant, never changes ($100)
    uint256 internal s_balance; // Stores the funded balance to avoid selfdestruct attacks using address(this).balance

    /**
     * Functions order:
     * - constructor
     * - receive
     * - fallback
     * - external
     * - public
     * - internal
     * - private
     * - view / pure
     */

    constructor(address priceFeedAddress) {
        i_creator = msg.sender;

        // Set the address of the priceFeed contract
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    /**
     * Explainer from: https://solidity-by-example.org/fallback
     * Ether is sent to contract
     *      is msg.data empty?
     *           /    \
     *         yes    no
     *         /       \
     *    receive()?  fallback()
     *      /     \
     *    yes     no
     *    /        \
     * receive()  fallback()
     */
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /** @notice Function for sending funds to the contract.
     *  @dev This implements price feeds as a library.
     */
    function fund() public payable virtual {
        // msg.value is handled as the first input parameter of getConversionRate()
        // as it is being used as a Library
        // with s_priceFeed used as the second input parameter
        if (msg.value.getConversionRate(s_priceFeed) <= MINIMUM_USD)
            revert FundMe__NotEnoughEthSent();

        /**
         *  The s_balance variable isn't needed for this function
         *  as it withdraws 100% of the funds in the contract anyway.
         *  It actually creates a problem if someone does perform a selfdestruct
         *  attack, since those funds are then not counted, and get stuck.
         *  So use another function withdrawSelfdestructFunds() to completely
         *  drain the contract. This is better as it allows the owner to fix the
         *  problem, without being accused of draining the main funds/prize.
         *  It is an example to show how to avoid selfdestruct attacks:
         *  https://solidity-by-example.org/hacks/self-destruct/
         */
        s_balance += msg.value;

        s_addressToAmountFunded[msg.sender] += msg.value;

        // If funder does not already exist, add to s_funders array
        address[] memory funders = s_funders;
        for (uint256 i = 0; i < funders.length; i++) {
            if (funders[i] == msg.sender) {
                return;
            }
        }
        s_funders.push(msg.sender);
    }

    /** @notice Function for allowing owner to withdraw all funds from the contract.
     *  @dev Does not require a reentrancy check as only the owner can call it and it withdraws all funds anyway.
     */
    function withdraw() external payable onlyOwner {
        // Check to make sure that the contract is not empty before attempting withdrawal
        if (s_balance == 0) revert FundMe__WithdrawNoFunds();

        address[] memory funders = s_funders;

        // Loop through all funders in s_addressToAmountFunded mapping and reset the funded value to 0
        for (
            uint256 funderIndex = 0;
            funderIndex < funders.length;
            funderIndex++
        ) {
            address funder = funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        // Reset the s_funders array to an empty array
        s_funders = new address[](0);

        // Create a temporary variable to store the s_balance value as a form of reentrancy protection
        // as it stores the s_balance value which can then be reset to 0 before the .call is made
        // so any reentrancy attack will fail as s_balance will be 0
        uint256 withdrawAmount = s_balance;

        // Reset the s_balance variable to 0 otherwise future full withdrawals will fail
        s_balance = 0;

        // ***********
        // SEND FUNDS
        // ***********
        (bool callSuccess, ) = owner().call{ value: withdrawAmount }("");
        if (!callSuccess) revert FundMe__WithdrawFailed();
    }

    /** @notice Function for allowing owner to withdraw any selfdestruct funds from the contract.
     *  @dev // TODO
     */
    function withdrawSelfdestructFunds() external payable onlyOwner {
        if (address(this).balance > s_balance) {
            uint256 selfdestructBalance = address(this).balance - s_balance;

            // ***********
            // SEND FUNDS
            // ***********
            (bool callSuccess, ) = owner().call{ value: selfdestructBalance }(
                ""
            );
            if (!callSuccess) revert FundMe__WithdrawSelfDestructFailed();
        } else {
            revert FundMe__WithdrawSelfDestructFailed();
        }
    }

    /** @notice Function for refunding deposits to funders on request.
     *  @dev Does not require nonReentrant modifier as s_addressToAmountFunded
     * is reset before sending funds, but retained here for completeness of this template.
     */
    function refund() external payable nonReentrant {
        uint256 refundAmount = s_addressToAmountFunded[msg.sender];
        if (refundAmount == 0) revert FundMe__RefundNoFunds();

        address[] memory funders = s_funders;

        // Resetting the funded amount before the refund is
        // sent stops reentrancy attacks on this function
        s_addressToAmountFunded[msg.sender] = 0;

        // Reduce s_balance by the refund amount
        s_balance -= refundAmount;

        // Remove specific funder from the s_funders array
        for (uint256 i = 0; i < funders.length; i++) {
            if (funders[i] == msg.sender) {
                // Move the element into the last place to delete
                s_funders[i] = s_funders[s_funders.length - 1];
                // Remove the last element
                s_funders.pop();
            }
        }

        // ***********
        // SEND FUNDS
        // ***********
        (bool callSuccess, ) = msg.sender.call{ value: refundAmount }("");
        if (!callSuccess) revert FundMe__RefundFailed();
    }

    /** @notice Getter function to get the i_creator address.
     *  @dev Public function to allow anyone to view the contract creator.
     *  @return address of the creator.
     */
    function getCreator() public view returns (address) {
        return i_creator;
    }

    /** @notice Getter function for a specific funder address based on their index in the s_funders array.
     *  @dev Allow public users to get list of all funders by iterating through the array.
     *  @param funderAddress The address of the funder to be found in s_funders array.
     *  @return uint256 index position of funderAddress.
     */
    function getFunderIndex(
        address funderAddress
    ) public view returns (uint256) {
        address[] memory funders = s_funders;
        uint256 index;

        for (uint256 i = 0; i < funders.length; i++) {
            if (funders[i] == funderAddress) {
                index = i;
                return index;
            }
        }
        revert FundMe__IndexNotFound();
    }

    /** @notice Getter function for a specific funder based on their index in the s_funders array.
     *  @dev // TODO
     */
    function getFunderAddress(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    /** @notice Getter function to convert an address to the total amount funded.
     *  @dev Public function to allow anyone to easily check the balance funded by any address.
     */
    function getAddressToAmountFunded(
        address funder
    ) public view returns (uint256) {
        return s_addressToAmountFunded[funder];
    }

    /** @notice Getter function to get the current price feed value.
     *  @dev Public function to allow anyone to check the current price feed value.
     */
    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    /** @notice Getter function to get the current balance of the contract.
     *  @dev Public function to allow anyone to check the current balance of the contract.
     */
    function getBalance() public view returns (uint256) {
        return s_balance;
    }

    /** @notice Getter function to get the s_funders array.
     *  @dev Public function to allow anyone to view the s_funders array.
     */
    function getFunders() public view returns (address[] memory) {
        return s_funders;
    }

    /** @notice Function for getting priceFeed version.
     *  @dev Public function to allow anyone to view the AggregatorV3Interface version.
     */
    function getPriceFeedVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }
}
