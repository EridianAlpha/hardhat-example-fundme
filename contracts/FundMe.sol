// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./PriceConverter.sol";
import "hardhat/console.sol";

// Error codes
error FundMe__NotOwner();
error FundMe__WithdrawFailed();
error FundMe__NotEnoughEthSent();

/** @title A contract for crowd funding
 *  @author EridianAlpha
 *  @notice This contract is to demo a sample funding contract
 *  @dev This implements price feeds as our library
 */
contract FundMe {
    // Type declarations
    using PriceConverter for uint256; // Extends uint256 (used from msg.value) to enable direct price conversion

    // State variables
    address[] internal s_funders;
    address private immutable i_owner; // Set in constructor
    AggregatorV3Interface internal s_priceFeed; // Set in constructor
    mapping(address => uint256) internal s_addressToAmountFunded;
    uint256 public constant MINIMUM_USD = 100 * 10**18; // Constant, never changes

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
        s_funders.push(msg.sender);
    }

    /** @notice Function for withdrawing funds from the contract
     *  @dev // TODO withdraw()
     */
    function withdraw() public payable onlyOwner {
        // TODO Add Re-entrancy Guard

        // Loop through all funder addresses and reset the funded value to 0
        address[] memory funders = s_funders;
        // Mappings can't be in memory, sorry!
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

        // TODO Test for call failing
        (bool callSuccess, ) = i_owner.call{ value: address(this).balance }("");
        if (!callSuccess) revert FundMe__WithdrawFailed();
    }

    /** @notice Function for getting priceFeed version
     *  @dev // TODO getPriceFeedVersion()
     */
    function getPriceFeedVersion() public view returns (uint256) {
        // AggregatorV3Interface priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        return s_priceFeed.version();
    }

    /** @notice Getter function for the contract owner
     *  @dev Used instead of the variable directly so the i_ isn't used everywhere
     */
    function getOwner() public view returns (address) {
        return i_owner;
    }

    /** @notice Getter function for a specific funder based on their index in the s_funders array
     *  @dev Allow public users to get list of all funders by iterating through the array
     */
    function getFunder(uint256 index) public view returns (address) {
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
}
