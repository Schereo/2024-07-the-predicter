// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, StdInvariant, console2} from "forge-std/Test.sol";
import {ThePredicterHandler} from "./ThePredicterHandler.t.sol";
import {ThePredicter} from "../../src/ThePredicter.sol";
import {ScoreBoard} from "../../src/ScoreBoard.sol";

contract Invariant is StdInvariant, Test {
    ThePredicterHandler handler;
    ThePredicter public thePredicter;
    ScoreBoard public scoreBoard;

    address public organizer = makeAddr("organizer");

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

        handler = new ThePredicterHandler(thePredicter, scoreBoard);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = handler.registerAndGetApproved.selector;

        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
        targetContract(address(handler));
    }

    function invariant_test() public {
        assertEq(address(thePredicter).balance, 0 ether);
    }
}
