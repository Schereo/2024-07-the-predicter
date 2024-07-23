// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ThePredicter} from "../../src/ThePredicter.sol";
import {ScoreBoard} from "../../src/ScoreBoard.sol";

contract Handler is Test {
    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;

    address public organizer = makeAddr("organizer");
    address[] public players;
    mapping(address => uint256) public numberOfPredictions;

    uint256 public lastCummulatedWithdrawal;
    uint16 public gameIndex;

    // uint256 public constant PLAYER_STARTING_BALANCE = 1 ether;

    constructor(ThePredicter _thePredicter, ScoreBoard _scoreBoard) {
        thePredicter = _thePredicter;
        scoreBoard = _scoreBoard;
    }

    function playerRegistersAndGetsApproved(address playerAddress) public {
        if (players.length == 30) {
            return;
        }
        hoax(playerAddress, 0.04 ether);
        thePredicter.register{value: 0.04 ether}();
        vm.prank(organizer);
        thePredicter.approvePlayer(playerAddress);
        players.push(playerAddress);
    }

    function playersPredictsGame(uint256 predictionIndex) public {
        if (players.length <= 10) {
            return;
        }
        predictionIndex = predictionIndex % 4; // Pending, First, Draw, Second
        for (uint256 i = 0; i < players.length; i++) {
            hoax(players[i], thePredicter.predictionFee());
            thePredicter.makePrediction{value: 0.0001 ether}(
                gameIndex,
                ScoreBoard.Result(predictionIndex)
            );
            numberOfPredictions[players[i]]++;
        }
    }

    function organizerSetsGameResult(uint256 resultIndex) public {
        if (players.length <= 10) {
            return;
        }
        // Don't allow the organizer to set the result to pending (index 0)
        resultIndex = (resultIndex % 3) + 1; // First, Draw, Second
        vm.prank(organizer);
        scoreBoard.setResult(gameIndex, ScoreBoard.Result(resultIndex));
        // All players withdraw after the last match
        if (gameIndex == scoreBoard.NUM_MATCHES() - 1) {
            playersWithdraw();
        }
        // After the organizer has set the result, advance to the next game
        if (gameIndex != scoreBoard.NUM_MATCHES() - 1) {
            gameIndex++;
        }
    }

    function playersWithdraw() private {
        for (uint256 i = 0; i < players.length; i++) {       
            if (numberOfPredictions[players[i]] != 0) {
                vm.prank(players[i]);
                thePredicter.withdraw();
                console2.log(
                    "Players balance after withdraw: ",
                    address(players[i]).balance
                );
                lastCummulatedWithdrawal += address(players[i]).balance;
            } else {
                console2.log("Player has no predictions");
            }
            // 40000000000000000
            // 41739130434782608
        }
    }

    function organizerWithdrawsPredicitonFees() public {
        vm.prank(organizer);
        thePredicter.withdrawPredictionFees();
    }

    function getPlayers() public view returns (address[] memory) {
        return players;
    }
}
