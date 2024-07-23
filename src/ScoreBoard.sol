// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {console2} from "forge-std/console2.sol";

contract ScoreBoard {
    uint256 private constant START_TIME = 1723752000; // Thu Aug 15 2024 20:00:00 GMT+0000
    uint256 public constant NUM_MATCHES = 9;

    enum Result {
        Pending,
        First,
        Draw,
        Second
    }

    struct PlayerPredictions {
        Result[NUM_MATCHES] predictions;
        bool[NUM_MATCHES] isPaid;
        uint8 predictionsCount; // @audit q: shouldn't be this equal to predictions.length?
        // @audit a: No, predictions.length will always be equal to NUM_MATCHES
    }

    // @audit-invalid gas: Owner var could be immutable
    address owner;
    address thePredicter;
    Result[NUM_MATCHES] public results;
    mapping(address players => PlayerPredictions) public playersPredictions;

    error ScoreBoard__UnauthorizedAccess();

    // @audit-invalid info: Owner is not a declared role in the readme, how is it different from organizer?
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert ScoreBoard__UnauthorizedAccess();
        }
        _;
    }

    modifier onlyThePredicter() {
        if (msg.sender != thePredicter) {
            revert ScoreBoard__UnauthorizedAccess();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setThePredicter(address _thePredicter) public onlyOwner {
        // @audit-invalid info: Zero address check
        thePredicter = _thePredicter;
    }

    // @audit q: What happens if a previously set result is overwritten?
    // @audit a: It does only matter for the last game after which players can withdraw their rewards, if changed during
    // reward withdrawal, players will get different rewards for the same predictions
    // => If the result is changed in a player's favor who has not withdrawn yet, the protocol might try to payout more funds
    // than it has
    function setResult(uint256 matchNumber, Result result) public onlyOwner {
        results[matchNumber] = result;
    }

    function confirmPredictionPayment(
        address player,
        uint256 matchNumber
    ) public onlyThePredicter {
        playersPredictions[player].isPaid[matchNumber] = true;
    }

    function setPrediction(
        address player,
        uint256 matchNumber,
        Result result
    ) public {
        // @audit-written medium: Math is wrong + magic numbers
        // Example: For the first match (number 0), users should be able to set predictions until 3600 seconds (1 hour) before the match starts
        //  1723752000 + 0 * 68400 - 68400 = 1723752000 - 68400 = 1723683600 => Thu Aug 15 2024 01:00:00 GMT+0000 (19 hours before the match)
        // @audit-written high: Anyone can set the predictions for a player, not only the player itself
        if (block.timestamp <= START_TIME + matchNumber * 68400 - 68400)
            playersPredictions[player].predictions[matchNumber] = result;
        playersPredictions[player].predictionsCount = 0;
        for (uint256 i = 0; i < NUM_MATCHES; ++i) {
            if (
                playersPredictions[player].predictions[i] != Result.Pending &&
                playersPredictions[player].isPaid[i]
            ) ++playersPredictions[player].predictionsCount;
        }
    }

    function clearPredictionsCount(address player) public onlyThePredicter {
        playersPredictions[player].predictionsCount = 0;
    }

    function getPlayerScore(address player) public view returns (int8 score) {
        for (uint256 i = 0; i < NUM_MATCHES; ++i) {
            if (
                playersPredictions[player].isPaid[i] &&
                playersPredictions[player].predictions[i] != Result.Pending
            ) {
                // @audit q: What happens if the player has not predicted every game?
                // @audit a: Predictions and results are initializd with Result.Pending. So for every unplayed match, the player will get 2 points
                // That is not an issue because the player's score will only get calculated when all games are played
                score += playersPredictions[player].predictions[i] == results[i]
                    ? int8(2)
                    : -1;
            }
        }
    }

    function isEligibleForReward(address player) public view returns (bool) {
        console2.log(
            "Prediciton count: ",
            playersPredictions[player].predictionsCount
        );
        return
            results[NUM_MATCHES - 1] != Result.Pending &&
            playersPredictions[player].predictionsCount > 1;
    }
}
