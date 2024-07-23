// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ThePredicter} from "../../src/ThePredicter.sol";
import {ScoreBoard} from "../../src/ScoreBoard.sol";

contract ThePredicterHandler is Test {
    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;

    address public organizer = makeAddr("organizer");
    address public stranger = makeAddr("stranger");

    constructor(ThePredicter _thePredicter, ScoreBoard _scoreBoard) {
        thePredicter = _thePredicter;
        scoreBoard = _scoreBoard;
    }

    function registerAndGetApproved() public {
        // REGISTER
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        // APPROVE
        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        // MAKE PREDICTIONS
        vm.startPrank(stranger);
        thePredicter.makePrediction{value: 0.0001 ether}(
            1,
            ScoreBoard.Result.Draw
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            2,
            ScoreBoard.Result.First
        );
        thePredicter.makePrediction{value: 0.0001 ether}(
            3,
            ScoreBoard.Result.First
        );
        vm.stopPrank();

        // SET RESULTS
        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.First);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        // WITHDRAW PREDICTION FEES
        // vm.startPrank(organizer);
        // // arithmetic underflow or overflow
        // if (address(thePredicter).balance > 0) {
        //     console.log("b4", address(thePredicter).balance); //40300000000000000
        //     thePredicter.withdrawPredictionFees();
        //     console.log("after", address(thePredicter).balance); //40000000000000000
        // }
        // // thePredicter.withdrawPredictionFees();
        // vm.stopPrank();
        //  assertEq(address(thePredicter).balance, 12e16);

        // WITHDRAW
        vm.startPrank(stranger);
        // console.log("b4", address(thePredicter).balance);
        thePredicter.withdraw();
        vm.stopPrank();
        // 1 - 0.04 - (0.001 * 3) = 0.9597 - After Entrance & Prediction Fees
        // (3 * 3 * .04e18) / 12 = 0.03e18 - Earned Reward
        // 0.9597 + 0.03 = 0.9897
        // assertEq(stranger.balance, 0.9897 ether);
        // assertEq(address(thePredicter).balance, 0 ether);
    }
}
