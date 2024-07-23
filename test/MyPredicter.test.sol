pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ThePredicter} from "../src/ThePredicter.sol";
import {ScoreBoard} from "../src/ScoreBoard.sol";

contract MyPredicterTest is Test {
    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;
    address public organizer = makeAddr("organizer");
    address public stranger = makeAddr("stranger");
    address public stranger2 = makeAddr("stranger2");

    function setUp() public {
        vm.startPrank(organizer);
        scoreBoard = new ScoreBoard();
        thePredicter = new ThePredicter(
            address(scoreBoard),
            0.04 ether, // entrance fee
            0.0001 ether // prediction fee
        );
        scoreBoard.setThePredicter(address(thePredicter));
        vm.stopPrank();
    }

    function test_canChangePredictionsAfterResultsAreSet() public {
        // REGISTER
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        // APPROVE
        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        vm.stopPrank();

        // ALL WRONG PREDICTIONS
        vm.startPrank(stranger);
        for (uint256 i = 0; i < 9; i++) {
            thePredicter.makePrediction{value: 0.0001 ether}(
                i,
                ScoreBoard.Result.Draw
            );
        }
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

        // ALL WRONG PREDICTIONS
        assertEq(scoreBoard.getPlayerScore(stranger), -9);

        // WITHDRAW PREDICTION FEES
        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        // ALL CORRECT PREDICTIONS
        vm.startPrank(stranger);
        for (uint256 i = 0; i < 9; i++) {
            scoreBoard.setPrediction(stranger, i, ScoreBoard.Result.First);
        }
        vm.stopPrank();

        assertEq(scoreBoard.getPlayerScore(stranger), 18);

        // WITHDRAW
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();
    }

    function test_oldNoRegistration() public {
        // DOES NOT PAY ENTRANCE FEE
        vm.startPrank(stranger);
        vm.deal(stranger, 0.0004 ether);
        vm.stopPrank();

        // PAYS ENTRANCE FEE
        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.warp(1);
        vm.startPrank(stranger);
        for (uint256 i = 0; i < 4; i++) {
            thePredicter.makePrediction{value: 0.0001 ether}(
                i,
                ScoreBoard.Result.First
            );
        }
        vm.stopPrank();

        vm.startPrank(stranger2);
        for (uint256 i = 0; i < 4; i++) {
            thePredicter.makePrediction{value: 0.0001 ether}(
                i,
                ScoreBoard.Result.First
            );
        }
        vm.stopPrank();

        vm.warp(2);
        vm.startPrank(organizer);
        scoreBoard.setResult(0, ScoreBoard.Result.First);
        scoreBoard.setResult(1, ScoreBoard.Result.Draw);
        scoreBoard.setResult(2, ScoreBoard.Result.First);
        scoreBoard.setResult(3, ScoreBoard.Result.First);
        scoreBoard.setResult(4, ScoreBoard.Result.First);
        scoreBoard.setResult(5, ScoreBoard.Result.First);
        scoreBoard.setResult(6, ScoreBoard.Result.First);
        scoreBoard.setResult(7, ScoreBoard.Result.First);
        scoreBoard.setResult(8, ScoreBoard.Result.First);
        vm.stopPrank();

        assertEq(scoreBoard.getPlayerScore(stranger), 5);

        vm.warp(3);
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.expectRevert(bytes("Failed to withdraw"));
        thePredicter.withdraw();
        vm.stopPrank();
    }

    // thePredicter::withdrawPredictionFees - @audit high, added check to prevent underflow or internal accounting for the prediction fee
    function test_intOverFlow() public {
        // REGISTER
        vm.startPrank(stranger);
        vm.deal(stranger, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        vm.startPrank(stranger2);
        vm.deal(stranger2, 1 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.stopPrank();

        // APPROVE
        vm.startPrank(organizer);
        thePredicter.approvePlayer(stranger);
        thePredicter.approvePlayer(stranger2);
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

        vm.startPrank(stranger2);
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

        vm.startPrank(organizer);
        thePredicter.withdrawPredictionFees();
        vm.stopPrank();

        // WITHDRAW
        vm.startPrank(stranger);
        thePredicter.withdraw();
        vm.stopPrank();

        vm.startPrank(stranger2);
        thePredicter.withdraw();
        vm.stopPrank();

        //000600000000000000

        // WITHDRAW PREDICTION FEES

        //  assertEq(address(thePredicter).balance, 12e16);
    }

    // @todo setPrediction - change different player's prediction other than your own

    //@todo reentrancy
}
