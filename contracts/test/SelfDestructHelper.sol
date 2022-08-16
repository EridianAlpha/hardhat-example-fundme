// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../FundMe.sol";
import "./SelfDestructAttack.sol";

contract SelfDestructHelper {
    FundMe fundMeContract;
    SelfDestructAttack selfDestructAttackContract1;
    SelfDestructAttack selfDestructAttackContract2;
    uint256 attackValue = 1000000000000000000;

    constructor(address priceFeedAddress) payable {
        fundMeContract = new FundMe(priceFeedAddress);

        selfDestructAttackContract1 = new SelfDestructAttack(
            payable(address(fundMeContract))
        );
        selfDestructAttackContract2 = new SelfDestructAttack(
            payable(address(fundMeContract))
        );
        console.log("INSIDE-5");
    }

    function initialFunding() public payable {
        console.log("INSIDE-50");

        console.log("address(this).balance: ");
        console.log(address(this).balance);

        (bool callSuccess, ) = address(fundMeContract).call{
            value: attackValue
        }("");
        callSuccess;

        (bool callSuccess1, ) = address(selfDestructAttackContract1).call{
            value: attackValue
        }(abi.encodeWithSignature("initialFunding()", 0, msg.sender));
        callSuccess1;

        console.log("address(fundMeContract).balance: ");
        console.log(address(fundMeContract).balance);
        console.log("address(selfDestructAttackContract1).balance: ");
        console.log(address(selfDestructAttackContract1).balance);
        console.log("address(selfDestructAttackContract2).balance: ");
        console.log(address(selfDestructAttackContract2).balance);
    }

    function selfDestructAttackContract2Address()
        public
        view
        returns (address)
    {
        return address(selfDestructAttackContract2);
    }

    function fundMeTransferOwnership(address newOwner) public {
        fundMeContract.transferOwnership(newOwner);
    }

    function fundMeGetOwner() public view returns (address) {
        return fundMeContract.getOwner();
    }

    function attack() public payable {
        console.log("INSIDE-6");
        selfDestructAttackContract1.attack();
    }

    function fundMeSelfDestructWithdraw() public payable {
        console.log("INSIDE-22");
        console.log("msg.sender");
        console.log(msg.sender);
        console.log("selfDestructAttackContract2");
        console.log(address(selfDestructAttackContract2));
        selfDestructAttackContract2.withdrawTest();
    }
}
