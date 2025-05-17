// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFT, NAME, SYMBOL} from "../src/NFT.sol";

contract NFTTest is Test {
    NFT public nft;
    uint256 public supply = 20;
    uint256 public premint = 5;
    address public team = makeAddr("team");
    uint256 public startTimestamp = block.timestamp + (10 * 60 * 60);
    uint256 public guaranteedSeconds = 24 * 60 * 60;
    uint256 public nonGuaranteedSeconds = 24 * 60 * 60;
    uint256 public guaranteedPrice = 1 ether;
    uint256 public nonGuaranteedPrice = 2 ether;
    uint256 public publicPrice = 5 ether;
    address[] guaranteedAllowlist;
    address[] nonGuaranteedAllowlist;

    function setUp() public {
        for (uint256 i = 10_000; i < 10_005; i++) {
            guaranteedAllowlist.push(address(uint160(i)));
        }

        for (uint256 i = 10_005; i < 10_015; i++) {
            nonGuaranteedAllowlist.push(address(uint160(i)));
        }

        nft = new NFT(
            supply,
            premint,
            team,
            startTimestamp,
            guaranteedSeconds,
            nonGuaranteedSeconds,
            guaranteedPrice,
            nonGuaranteedPrice,
            publicPrice,
            guaranteedAllowlist,
            nonGuaranteedAllowlist
        );
    }

    function test_Info() public view {
        assertEq(nft.name(), NAME);
        assertEq(nft.symbol(), SYMBOL);
    }

    function test_Premint() public view {
        for (uint256 i = 0; i < premint; i++) {
            assertEq(nft.ownerOf(i), team);
        }
    }

    function test_GuaranteedMint() public {
        vm.expectRevert("Mint is not live.");
        vm.deal(address(uint160(10000)), guaranteedPrice);
        vm.startPrank(address(uint160(10000)));
        nft.mint{value: guaranteedPrice}();

        vm.warp(block.timestamp + 10 * 60 * 60);

        for (uint256 i = 10_000; i < 10_005; i++) {
            vm.deal(address(uint160(i)), guaranteedPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: guaranteedPrice}();
        }

        for (uint256 i = 10_005; i < 10_015; i++) {
            vm.expectRevert("Cannot mint.");
            vm.deal(address(uint160(i)), guaranteedPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: guaranteedPrice}();
        }

        vm.expectRevert("Cannot mint.");
        vm.deal(address(uint160(10_020)), guaranteedPrice);
        vm.startPrank(address(uint160(10_020)));
        nft.mint{value: guaranteedPrice}();
    }

    function test_NonGuaranteedMint() public {
        vm.expectRevert("Mint is not live.");
        vm.deal(address(uint160(10000)), nonGuaranteedPrice);
        vm.startPrank(address(uint160(10000)));
        nft.mint{value: nonGuaranteedPrice}();

        vm.warp(block.timestamp + 10 * 60 * 60 + guaranteedSeconds);

        for (uint256 i = 10_000; i < 10_005; i++) {
            vm.deal(address(uint160(i)), nonGuaranteedPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: nonGuaranteedPrice}();
        }

        vm.expectRevert("Cannot mint.");
        vm.deal(address(uint160(10_020)), nonGuaranteedPrice);
        vm.startPrank(address(uint160(10_020)));
        nft.mint{value: nonGuaranteedPrice}();

        for (uint256 i = 10_005; i < 10_015; i++) {
            vm.deal(address(uint160(i)), nonGuaranteedPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: nonGuaranteedPrice}();
        }
    }

    function test_PublicMint() public {
        vm.expectRevert("Mint is not live.");
        vm.deal(address(uint160(10000)), publicPrice);
        vm.startPrank(address(uint160(10000)));
        nft.mint{value: publicPrice}();

        vm.warp(block.timestamp + 10 * 60 * 60 + guaranteedSeconds + nonGuaranteedSeconds);

        for (uint256 i = 10_000; i < 10_005; i++) {
            vm.deal(address(uint160(i)), publicPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: publicPrice}();
        }

        vm.expectRevert("Not paid for.");
        vm.deal(address(uint160(10_020)), 0);
        vm.startPrank(address(uint160(10_020)));
        nft.mint{value: 0}();

        for (uint256 i = 10_005; i < 10_010; i++) {
            vm.deal(address(uint160(i)), publicPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: publicPrice}();
        }

        for (uint256 i = 10_020; i < 10_025; i++) {
            vm.deal(address(uint160(i)), publicPrice);
            vm.startPrank(address(uint160(i)));
            nft.mint{value: publicPrice}();
        }
    }

    function test_GetPhase() public {
        (NFT.MintPhase _mintPhase, uint256 _secondsLeft, uint256 _price, uint256 _currentSupply, uint256 _supply) =
            nft.getPhase();

        assertEq(_mintPhase == NFT.MintPhase.NotStarted, true);
        assertEq(_secondsLeft, 10 * 60 * 60);
        assertEq(_price, guaranteedPrice);
        assertEq(_currentSupply, nft.totalSupply());
        assertEq(_supply, supply);

        vm.warp(block.timestamp + 10 * 60 * 60);
        (_mintPhase, _secondsLeft, _price, _currentSupply, _supply) = nft.getPhase();

        assertEq(_mintPhase == NFT.MintPhase.Guaranteed, true);
        assertEq(_secondsLeft, guaranteedSeconds);
        assertEq(_price, guaranteedPrice);
        assertEq(_currentSupply, nft.totalSupply());
        assertEq(_supply, supply);

        vm.warp(block.timestamp + 4 * 60 * 60);
        (_mintPhase, _secondsLeft, _price, _currentSupply, _supply) = nft.getPhase();

        assertEq(_mintPhase == NFT.MintPhase.Guaranteed, true);
        assertEq(_secondsLeft, guaranteedSeconds - 4 * 60 * 60);
        assertEq(_price, guaranteedPrice);
        assertEq(_currentSupply, nft.totalSupply());
        assertEq(_supply, supply);

        vm.warp(block.timestamp + 21 * 60 * 60);
        (_mintPhase, _secondsLeft, _price, _currentSupply, _supply) = nft.getPhase();

        assertEq(_mintPhase == NFT.MintPhase.NonGuaranteed, true);
        assertEq(_secondsLeft, nonGuaranteedSeconds - 1 * 60 * 60);
        assertEq(_price, nonGuaranteedPrice);
        assertEq(_currentSupply, nft.totalSupply());
        assertEq(_supply, supply);

        vm.warp(block.timestamp + 23 * 60 * 60);
        (_mintPhase, _secondsLeft, _price, _currentSupply, _supply) = nft.getPhase();

        assertEq(_mintPhase == NFT.MintPhase.Public, true);
        assertEq(_secondsLeft, 0);
        assertEq(_price, publicPrice);
        assertEq(_currentSupply, nft.totalSupply());
        assertEq(_supply, supply);
    }
}
