// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ScoreBoard} from "./ScoreBoard.sol";

contract ThePredicter {
    using Address for address payable;

    uint256 private constant START_TIME = 1723752000; // Thu Aug 15 2024 20:00:00 GMT+0000

    enum Status {
        Unknown,
        Pending,
        Approved,
        Canceled
    }

    address public organizer;
    address[] public players;
    uint256 public entranceFee;
    uint256 public predictionFee;
    ScoreBoard public scoreBoard;
    mapping(address players => Status) public playersStatus;

    error ThePredicter__IncorrectEntranceFee();
    error ThePredicter__RegistrationIsOver();
    error ThePredicter__IncorrectPredictionFee();
    error ThePredicter__AllPlacesAreTaken();
    error ThePredicter__CannotParticipateTwice();
    error ThePredicter__NotEligibleForWithdraw();
    error ThePredicter__PredictionsAreClosed();
    error ThePredicter__UnauthorizedAccess();

    // @audit info: Missing zero address checks
    constructor(
        address _scoreBoard,
        uint256 _entranceFee,
        uint256 _predictionFee
    ) {
        organizer = msg.sender;
        scoreBoard = ScoreBoard(_scoreBoard);
        entranceFee = _entranceFee;
        predictionFee = _predictionFee;
    }

    // @audit q: Can users enter again after they have been approved?
    // @audit a: Yes, but they have to pay again and overwirte their previous registration
    // @audit gas: Can be external since it is not called by the contract
    function register() public payable {
        if (msg.value != entranceFee) {
            revert ThePredicter__IncorrectEntranceFee();
        }

        // 14400 == 4 hours
        if (block.timestamp > START_TIME - 14400) {
            revert ThePredicter__RegistrationIsOver();
        }

        if (playersStatus[msg.sender] == Status.Pending) {
            revert ThePredicter__CannotParticipateTwice();
        }

        playersStatus[msg.sender] = Status.Pending;
    }

    function cancelRegistration() public {
        if (playersStatus[msg.sender] == Status.Pending) {
            // @audit-written high: Reentrancy possible, users can drain the contract balance
            (bool success, ) = msg.sender.call{value: entranceFee}("");
            require(success, "Failed to withdraw");
            playersStatus[msg.sender] = Status.Canceled;
            return;
        }
        revert ThePredicter__NotEligibleForWithdraw();
    }

    // @audit low: Users can enter the tournament multiple times when they re-register after
    // being approved
    function approvePlayer(address player) public {
        if (msg.sender != organizer) {
            revert ThePredicter__UnauthorizedAccess();
        }
        if (players.length >= 30) {
            revert ThePredicter__AllPlacesAreTaken();
        }
        if (playersStatus[player] == Status.Pending) {
            playersStatus[player] = Status.Approved;
            players.push(player);
        }
    }

    // @audit gas: Can be external since it is not called by the contract
    // @audit medium: Not-approved players can make predictions, and thus avoid paying the entrance fee
    function makePrediction(
        uint256 matchNumber,
        ScoreBoard.Result prediction
    ) public payable {
        if (msg.value != predictionFee) {
            revert ThePredicter__IncorrectPredictionFee();
        }
        // @audit medium: Math is wrong + magic numbers same as in ScoreBoard.sol
        // Example: For the first match (number 0), users should be able to set predictions until 3600 seconds (1 hour) before the match starts
        //  1723752000 + 0 * 68400 - 68400 = 1723752000 - 68400 = 1723683600 => Thu Aug 15 2024 01:00:00 GMT+0000 (19 hours before the match)
        if (block.timestamp > START_TIME + matchNumber * 68400 - 68400) {
            revert ThePredicter__PredictionsAreClosed();
        }

        scoreBoard.confirmPredictionPayment(msg.sender, matchNumber);
        scoreBoard.setPrediction(msg.sender, matchNumber, prediction);
    }

    // @audit low: When called multiple times, more than the prediction fee can be withdrawn
    // @audit gas: Can be external since it is not called by the contract
    function withdrawPredictionFees() public {
        if (msg.sender != organizer) {
            revert ThePredicter__NotEligibleForWithdraw();
        }
        console.log("balance", address(this).balance);
        console.log(
            " - players.length * entranceFee",
            players.length * entranceFee
        );
        //@audit high, added check to prevent underflow or internal accounting for the prediction fee
        //          balance 600000000000000
        //    - players.length * entranceFee 80000000000000000

        //         //  balance 80600000000000000
        //    - players.length * entranceFee 80000000000000000
        //   fees 600000000000000
        //   reward 40000000000000000
        //   reward 40000000000000000
        uint256 fees = address(this).balance - players.length * entranceFee;
        console.log("fees", fees);
        (bool success, ) = msg.sender.call{value: fees}("");
        require(success, "Failed to withdraw");
    }

    // @audit medium: End of the tournament is not checked, allowing players
    // to withdraw their rewards before the organizer sets the final scores
    // if they have placed a wrong prediction
    // @audit gas: Can be external since it is not called by the contract
    function withdraw() public {
        if (!scoreBoard.isEligibleForReward(msg.sender)) {
            revert ThePredicter__NotEligibleForWithdraw();
        }

        int8 score = scoreBoard.getPlayerScore(msg.sender);

        int8 maxScore = -1;
        // @audit info: totalPositivePoints can be a uint256, since it can never be negative
        int256 totalPositivePoints = 0;

        // @audit e: Loop through all players and get the maximum score and sum of all positive scores
        for (uint256 i = 0; i < players.length; ++i) {
            int8 cScore = scoreBoard.getPlayerScore(players[i]);
            if (cScore > maxScore) maxScore = cScore;
            if (cScore > 0) totalPositivePoints += cScore;
        }

        // @audit e: Check if at least a single player has a positive score and the player has a negative score
        if (maxScore > 0 && score <= 0) {
            revert ThePredicter__NotEligibleForWithdraw();
        }
        // @audit q: Does casting to unsiged numbers remove any negative values?
        // @audit a: Should be safe here since negative scores
        uint256 shares = uint8(score);
        // @audit gas: Unnecessary cast, totalPositivePoints could also be a uint256 since it can never be negative
        uint256 totalShares = uint256(totalPositivePoints);
        uint256 reward = 0;

        // @audit e: When no one has a positive score return the entrance fee else calculate the players share
        // @audit low: Division by 0, if everyone has a negative or zero score totalShares will be 0
        reward = maxScore < 0
            ? entranceFee // @audit q: Hmm I'm not sure about this calculation. If every player withdraws not more than the total entrance fee should be withdrawn. // Let's state an invariant: The total amount of rewards withdrawn by all players should not exceed the total entrance fee paid by all players
            : (shares * players.length * entranceFee) / totalShares;

        console.log("reward", reward);
        if (reward > 0) {
            scoreBoard.clearPredictionsCount(msg.sender);
            (bool success, ) = msg.sender.call{value: reward}("");
            require(success, "Failed to withdraw");
        }
    }

    // getter for players length
    function getPlayersLength() public view returns (uint256) {
        return players.length;
    }
}
