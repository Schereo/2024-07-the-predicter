// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console2} from "forge-std/console2.sol";

import {ThePredicter, ScoreBoard} from "../../src/ThePredicter.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test {

    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;
    Handler public handler;
    address public organizer = makeAddr("organizer");

    function setUp() public {
        vm.startPrank(organizer);
        scoreBoard = new ScoreBoard();
        thePredicter = new ThePredicter(
            address(scoreBoard),
            0.04 ether,
            0.0001 ether
        );
        scoreBoard.setThePredicter(address(thePredicter));
        vm.stopPrank();

        handler = new Handler(thePredicter, scoreBoard);
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = Handler.playerRegistersAndGetsApproved.selector;
        selectors[1] = handler.playersPredictsGame.selector;
        selectors[2] = handler.playersPredictsGame.selector;
        selectors[3] = handler.playersPredictsGame.selector;
        selectors[4] = handler.playersPredictsGame.selector;
        selectors[5] = handler.organizerSetsGameResult.selector;
        selectors[6] = handler.organizerWithdrawsPredicitonFees.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));  
    }

    function invariant_playerWithdrawlsEqualsEntranceFee() public view {
        // Wait until the last match is over to evaulate invariant
        // Not recommende by the docs: https://book.getfoundry.sh/forge/invariant-testing#conditional-invariants
        if (scoreBoard.results(scoreBoard.NUM_MATCHES() - 1) == ScoreBoard.Result.Pending) {
            return;
        }
        console2.log("Last cummulatd withdrawal: ", handler.lastCummulatedWithdrawal());
        console2.log("Player in the game: ", handler.getPlayers().length);
        assertEq(handler.lastCummulatedWithdrawal(), thePredicter.entranceFee() * handler.getPlayers().length);
    }
    

    

}