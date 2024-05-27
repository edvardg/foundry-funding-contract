// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployer = new DeployFundMe();
        fundMe = deployer.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() external view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsSender() external view {
        //        assertEq(fundMe.i_owner(), address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersion() external view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() external {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() external {
        vm.prank(USER);

        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() external {
        vm.prank(USER);

        fundMe.fund{value: SEND_VALUE}();
        address founder = fundMe.getFunder(0);
        assertEq(founder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() external funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() external funded {
        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }

    function testWithdrawFromMultipleFunders() external funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, fundMe.getOwner().balance);
    }

    function testWithdrawCheaperFromMultipleFunders() external funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdrawCheaper();

        // Assert
        assertEq(address(fundMe).balance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, fundMe.getOwner().balance);
    }
}
