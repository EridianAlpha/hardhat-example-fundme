// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../FundMe.sol";
import "./SelfDestructAttack.sol";

/**
 * This contract is used to test the .call failing in FundMe.sol function withdrawSelfdestructFunds().
 *
 * The reason this contract causes the .call to fail is because it doesn't have a receive()
 * or fallback() function so the withdrawn and refunded ETH can't be accepted
 * but I still need to send funds to allow this contract to pass the "zero balance fails" tests
 * so there is a specific payable function for sending those initial funds initialFunding().
 * This contract also requires multiple deployments of the SelfDestructAttack contract
 * which are needed to setup the attack conditions to allow the withdrawal to be accessible.
 */
contract SelfDestructHelper {
    FundMe fundMeContract;
    SelfDestructAttack selfDestructAttackContract1;
    SelfDestructAttack selfDestructAttackContract2;
    uint256 attackValue = 1000000000000000000; // 1 ETH

    constructor(address priceFeedAddress) {
        // Deploy a new FundMe contract
        fundMeContract = new FundMe(priceFeedAddress);

        // First contract needed to perform attack
        selfDestructAttackContract1 = new SelfDestructAttack(
            payable(address(fundMeContract))
        );

        // Second contract needed to perform withdrawal
        selfDestructAttackContract2 = new SelfDestructAttack(
            payable(address(fundMeContract))
        );
    }

    function initialFunding() public payable {
        // Fund the fundMeContract with initial funds
        // Call picked up by receive() function and passed to fund()
        (bool callSuccess, ) = address(fundMeContract).call{
            value: attackValue
        }("");
        callSuccess;

        // Fund selfDestructAttackContract1 to perform initial attack
        // Call specific function name using abi.encodeWithSignature() as no
        // receive() or fallback() exists and contract constructor is not "payable"
        (bool callSuccess1, ) = address(selfDestructAttackContract1).call{
            value: attackValue
        }(abi.encodeWithSignature("initialFunding()", 0, msg.sender));
        callSuccess1;
    }

    // Function used in test to change owner of deployed FundMe contract
    // to allow withdrawal function to be accessible
    function selfDestructAttackContract2Address()
        public
        view
        returns (address)
    {
        return address(selfDestructAttackContract2);
    }

    // Exposes the ownership transfer function in FundMe for the test
    function fundMeTransferOwnership(address newOwner) public {
        fundMeContract.transferOwnership(newOwner);
    }

    // Exposes the attack function in FundMe for the test
    function attack() public payable {
        selfDestructAttackContract1.attack();
    }

    // Exposes the withdrawal function in FundMe for the test
    function fundMeSelfDestructWithdraw() public payable {
        selfDestructAttackContract2.fundMeContractWithdrawSelfdestructFunds();
    }
}
