// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
import "hardhat/console.sol";

// Error codes
error FundMe__NotOwner();
error FundMe__RefundFailed();
error FundMe__RefundNoFunds();
error FundMe__IndexNotFound();
error FundMe__WithdrawFailed();
error FundMe__WithdrawNoFunds();
error FundMe__NotEnoughEthSent();

/** @title A template contract for funding and withdrawals
 *  @author EridianAlpha
 *  @notice This contract is to demo a sample funding contract
 *  @dev Chainlink is used to implement price feeds
 */
contract FundMe is ReentrancyGuard {
    // Type declarations
    using PriceConverter for uint256; // Extends uint256 (used from msg.value) to enable direct price conversion

    // State variables
    address[] internal s_funders;
    address private immutable i_owner; // Set in constructor
    AggregatorV3Interface internal s_priceFeed; // Set in constructor
    mapping(address => uint256) internal s_addressToAmountFunded;
    uint256 public constant MINIMUM_USD = 100 * 10**18; // Constant, never changes ($100)

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

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
        /**
         * Initialize the contract owner as the deployer address.
         * The i_ shows that this is an immutable variable,
         * as it is only set here inside the constructor and then never changed again.
         * Not great for a design if you do want to change the owner in future, but shows how immutable variables work.
         * Would be more useful if it was a creator variable e.g."i_creator" as the creator will never change.
         */
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
    }

    /**
     * Explainer from: https://solidity-by-example.org/fallback
     * Ether is sent to contract
     *      is msg.data empty?
     *          /   \
     *         yes  no
     *         /     \
     *    receive()?  fallback()
     *     /   \
     *   yes   no
     *  /        \
     * receive()  fallback()
     */
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /** @notice Function for sending funds to the contract
     *  @dev This implements price feeds as a library
     */
    function fund() public payable virtual {
        if (msg.value.getConversionRate(s_priceFeed) <= MINIMUM_USD)
            revert FundMe__NotEnoughEthSent();

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

    /** @notice Function for allowing owner to withdraw all funds from the contract
     *  @dev Does not require a reentrancy check as only the owner can call it and it withdraws all funds anyway
     */
    function withdraw() external payable onlyOwner {
        // Check to make sure that the contract is not empty before attempting withdrawal
        if (address(this).balance == 0) revert FundMe__WithdrawNoFunds();

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

        (bool callSuccess, ) = i_owner.call{ value: address(this).balance }("");
        if (!callSuccess) revert FundMe__WithdrawFailed();
    }

    /** @notice Function for refunding deposits to funders on request
     *  @dev Does not require nonReentrant modifier as s_addressToAmountFunded is reset, but retained here for completeness of this template
     */
    function refund() external payable nonReentrant {
        uint256 refundAmount = s_addressToAmountFunded[msg.sender];
        if (refundAmount == 0) revert FundMe__RefundNoFunds();

        address[] memory funders = s_funders;

        // Resetting the funded amount before the refund is
        // sent stops reentrancy attacks on this function
        s_addressToAmountFunded[msg.sender] = 0;

        // Remove specific funder from the s_funders array
        for (uint256 i = 0; i < funders.length; i++) {
            if (funders[i] == msg.sender) {
                // Move the last element into the place to delete
                s_funders[i] = s_funders[s_funders.length - 1];
                // Remove the last element
                s_funders.pop();
            }
        }

        (bool callSuccess, ) = msg.sender.call{ value: refundAmount }("");
        if (!callSuccess) revert FundMe__RefundFailed();
    }

    /** @notice Function for getting priceFeed version
     *  @dev // TODO getPriceFeedVersion()
     */
    function getPriceFeedVersion() public view returns (uint256) {
        // AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        return s_priceFeed.version();
    }

    /** @notice Getter function for the contract owner
     *  @dev Used instead of the variable directly so the i_ is not used everywhere
     */
    function getOwner() public view returns (address) {
        return i_owner;
    }

    /** @notice Getter function for a specific funder address based on their index in the s_funders array
     *  @dev Allow public users to get list of all funders by iterating through the array
     */
    function getFunderIndex(address funderAddress)
        public
        view
        returns (uint256)
    {
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

    /** @notice Getter function for a specific funder based on their index in the s_funders array
     *  @dev // TODO
     */
    function getFunderAddress(uint256 index) public view returns (address) {
        return s_funders[index];
    }

    /** @notice Getter function to convert an address to the total amount funded
     *  @dev Public function to allow anyone to easily check the balance funded by any address
     */
    function getAddressToAmountFunded(address funder)
        public
        view
        returns (uint256)
    {
        return s_addressToAmountFunded[funder];
    }

    /** @notice Getter function to get the current price feed value
     *  @dev Public function to allow anyone to easily check the current price feed value
     */
    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }

    /** @notice Getter function to get the current balance of the contract
     *  @dev Public function to allow anyone to easily check the current balance of the contract
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /** @notice Getter function to get the s_funders array
     *  @dev Public function to allow anyone to easily view the s_funders array
     */
    function getFunders() public view returns (address[] memory) {
        // address[] memory funders = s_funders;
        return s_funders;
    }
}
