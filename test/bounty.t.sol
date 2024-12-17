// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {console} from "../lib/forge-std/src/Test.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {bounty} from "../src/bounty.sol";

contract BountyTest is Test {
    bounty _bounty;
    address constant owner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address user;
    address watcher;

    function setUp() public payable {
        user = address(0xBEEF);
        watcher = address(0xCAFE);
        vm.deal(user, 1 ether);
        vm.deal(watcher, 1 ether);

        _bounty = new bounty();
        console.log("Setup complete");
    }

    function testDeploy() public payable {
        new bounty();
        console.log("Deploy successful");
    }

    function testProposeBounty() public {
        vm.startPrank(user);
        uint256 tokenId = _bounty.propose(unicode"🎨", "Create a logo");
        vm.stopPrank();

        (
            string memory emojis,
            string memory text,
            address token,
            uint256 amount,
            bounty.Status status,
            address watcher
        ) = _bounty.requests(tokenId);

        assertEq(uint256(status), uint256(bounty.Status.Pending));
        assertEq(emojis, unicode"🎨");
        assertEq(text, "Create a logo");
        console.log("Proposal created with token ID:", tokenId);
    }

    function testCannotProposeExisting() public {
        vm.startPrank(user);
        uint256 tokenId = _bounty.propose(unicode"🎨", "Create a logo");

        (
            string memory emojis,
            string memory text,
            address token,
            uint256 amount,
            bounty.Status status,
            address watcher
        ) = _bounty.requests(tokenId);

        assertEq(emojis, unicode"🎨");
        assertEq(text, "Create a logo");
        console.log("First proposal token ID:", tokenId);

        vm.expectRevert(bounty.Exists.selector);
        _bounty.propose(unicode"🎨", "Create a logo");
        vm.stopPrank();
        console.log("Duplicate proposal properly rejected");
    }

    function testRequestBounty() public {
        address token = address(0x1111111111111111111111111111111111111111);
        uint256 amount = 1000;

        vm.startPrank(owner);
        uint256 tokenId = _bounty.request(unicode"🎨", "Create a logo", token, amount, watcher);
        vm.stopPrank();

        (
            string memory emojis,
            string memory text,
            address tokenAddr,
            uint256 tokenAmount,
            bounty.Status status,
            address watcherAddr
        ) = _bounty.requests(tokenId);

        assertEq(uint256(status), uint256(bounty.Status.Approved));
        assertEq(tokenAddr, token);
        assertEq(tokenAmount, amount);
        assertEq(watcherAddr, watcher);
        assertEq(_bounty.ownerOf(tokenId), watcher);
        assertEq(emojis, unicode"🎨");

        console.log("Bounty requested with token ID:", tokenId);
        console.log("Token:", token);
        console.log("Amount:", amount);
        console.log("Watcher:", watcher);
    }

    function testBountyStatus() public {
        // Create pending bounty
        vm.startPrank(user);
        uint256 pendingId = _bounty.propose(unicode"🎨", "Pending bounty");
        (,,,, bounty.Status pendingStatus,) = _bounty.requests(pendingId);
        assertEq(uint256(pendingStatus), uint256(bounty.Status.Pending));
        console.log("Created pending bounty:", pendingId);
        vm.stopPrank();

        // Create approved bounty - use the SAME emojis and text as an existing bounty
        vm.startPrank(owner);
        uint256 approvedId =
            _bounty.request(unicode"🎨", "Pending bounty", address(0), 1000, watcher);
        (,,,, bounty.Status approvedStatus,) = _bounty.requests(approvedId);
        assertEq(uint256(approvedStatus), uint256(bounty.Status.Approved));
        console.log("Created approved bounty:", approvedId);
        vm.stopPrank();

        // Create and reject bounty
        vm.prank(user);
        uint256 toRejectId = _bounty.propose(unicode"❌", "To reject bounty");
        vm.startPrank(owner);
        _bounty.reject(toRejectId);
        vm.stopPrank();
        (,,,, bounty.Status rejectedStatus,) = _bounty.requests(toRejectId);
        assertEq(uint256(rejectedStatus), uint256(bounty.Status.Rejected));
        console.log("Created rejected bounty:", toRejectId);

        // Get arrays by status
        uint256[] memory pending = _bounty.getBountiesByStatus(bounty.Status.Pending);
        uint256[] memory approved = _bounty.getBountiesByStatus(bounty.Status.Approved);
        uint256[] memory rejected = _bounty.getBountiesByStatus(bounty.Status.Rejected);

        console.log("Pending bounties count:", pending.length);
        console.log("Approved bounties count:", approved.length);
        console.log("Rejected bounties count:", rejected.length);

        assertEq(pending.length, 0); // Should be 0 as the pending was converted to approved
        assertEq(approved.length, 1); // Should be 1
        assertEq(rejected.length, 1); // Should be 1

        console.log("Status checks passed");
    }

    function testFullLifecycle() public {
        // Propose
        vm.startPrank(user);
        uint256 tokenId = _bounty.propose(unicode"🎨", "Create a logo");

        (,,,, bounty.Status proposeStatus,) = _bounty.requests(tokenId);
        assertEq(uint256(proposeStatus), uint256(bounty.Status.Pending));
        console.log("Proposed bounty:", tokenId);
        vm.stopPrank();

        // Request/Approve
        address token = address(0x1111111111111111111111111111111111111111);
        vm.startPrank(owner);
        _bounty.request(unicode"🎨", "Create a logo", token, 1000, watcher);
        vm.stopPrank();

        (,,,, bounty.Status approveStatus,) = _bounty.requests(tokenId);
        assertEq(uint256(approveStatus), uint256(bounty.Status.Approved));
        console.log("Approved bounty");

        // Complete
        address recipient = address(0x2222222222222222222222222222222222222222);
        vm.prank(watcher);
        _bounty.complete(tokenId, recipient);

        (,,,, bounty.Status completeStatus,) = _bounty.requests(tokenId);
        assertEq(uint256(completeStatus), uint256(bounty.Status.Completed));
        assertEq(_bounty.ownerOf(tokenId), recipient);
        console.log("Completed bounty");
        console.log("Full lifecycle completed successfully");
    }
}
