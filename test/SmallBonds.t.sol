// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solbase/tokens/ERC20/ERC20.sol";

import "../src/SmallBondsFactory.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("", "", 18) {}

    function mint(address guy, uint256 wad) public {
        _mint(guy, wad);
    }
}

contract SmallBondsTest is Test {
    SmallBondsFactory factory;
    SmallBonds bonds;
    address input; // give
    address output; // want

    function setUp() public {
        factory = new SmallBondsFactory();
        input = address(new MockERC20());
        output = address(new MockERC20());
        bonds = SmallBonds(factory.create(keccak256(abi.encode(420)), output, input, 5 days));
    }

    function testCreate() public {
        address predictedAddress =
            factory.predictDeterministicAddress(keccak256(abi.encode(420)), output, input, 5 days);

        bonds.initialize(address(this));

        assertEq(address(bonds), predictedAddress);
        assertEq(bonds.term(), 5 days);
        assertEq(bonds.outputToken(), output);
        assertEq(bonds.inputToken(), input);
        assertEq(bonds.owner(), address(this));
    }

    function testMulticallCreate() public {
        bytes[] memory calls = new bytes[](3);

        uint256 salt = uint256(keccak256(abi.encode(1)));

        calls[0] = abi.encodeWithSelector(SmallBondsFactory.create.selector, salt, input, output, 1 days);
        calls[1] = abi.encodeWithSelector(SmallBondsFactory.create.selector, salt + 1, input, output, 3 days);
        calls[2] = abi.encodeWithSelector(SmallBondsFactory.create.selector, salt + 2, input, output, 5 days);

        factory.multicall(calls);
    }

    function testDecay() public {
        deal(address(output), address(bonds), 100 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        uint256 spot1 = bonds.spotPrice();

        vm.warp(block.timestamp + 1 days);
        uint256 spot2 = bonds.spotPrice();

        vm.warp(block.timestamp + 1 days);
        uint256 spot3 = bonds.spotPrice();

        vm.warp(block.timestamp + 365 days);
        uint256 spot4 = bonds.spotPrice();

        assertEq(spot1 * 950 / 1000, spot2);
        assertEq(spot1 * 925 / 1000, spot3);
        assertEq(spot1 * 900 / 1000, spot4);
    }

    function testManagement() public {
        deal(address(output), address(bonds), 100 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        // test access control
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.setVirtualInputReserves(42069 ether);

        // test access control
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.setHalfLife(5 days);

        // test access control
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.setLevelBips(8_000);

        // test access control
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.setLastUpdate();

        assertEq(bonds.owner(), address(this));
        assertEq(bonds.virtualInputReserves(), 1000 ether);
        assertEq(bonds.halfLife(), 1 days);
        assertEq(bonds.levelBips(), 9_000);
        assertEq(bonds.lastUpdate(), block.timestamp);

        // test updatePricing()
        vm.warp(block.timestamp + 60 seconds);

        // test access control
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.updatePricing(2000 ether, 5000 ether, 5 days, 10_000, true, true);

        bonds.updatePricing(2000 ether, 5000 ether, 5 days, 10_000, true, true);

        assertEq(bonds.owner(), address(this));
        assertEq(bonds.virtualInputReserves(), 2000 ether);
        assertEq(bonds.virtualOutputReserves(), 5000 ether);
        assertEq(bonds.halfLife(), 5 days);
        assertEq(bonds.levelBips(), 10_000);
        assertEq(bonds.lastUpdate(), block.timestamp);

        // make sure contract cannot be initialized twice
        vm.expectRevert();
        vm.prank(address(0xbad));
        bonds.initialize(address(0xbad));
    }

    function testBondPurchase() public {
        address alice = address(0xAAAA);
        uint256 expectedAmountOut = 99900099900099900;

        deal(address(output), address(bonds), 100 ether);
        deal(address(input), alice, 1 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        vm.prank(alice);
        MockERC20(input).approve(address(bonds), 1 ether);

        vm.prank(alice);
        uint256 amountOut = bonds.purchaseBond(alice, 1 ether, 0);

        (uint256 owed, uint256 redeemed, uint256 creation) = bonds.bondOf(alice, 0);

        assertEq(amountOut, expectedAmountOut);
        assertEq(owed, expectedAmountOut);
        assertEq(redeemed, 0);
        assertEq(creation, block.timestamp);
        assertEq(bonds.virtualInputReserves(), 1000 ether + 1 ether);
    }

    function testBondRedemptionFull() public {
        address alice = address(0xAAAA);
        uint256 expectedAmountOut = 99900099900099900;

        deal(address(output), address(bonds), 100 ether);
        deal(address(input), alice, 1 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        vm.startPrank(alice);
        MockERC20(input).approve(address(bonds), 1 ether);

        uint256 balBefore = MockERC20(output).balanceOf(alice);
        bonds.purchaseBond(alice, 1 ether, 0);

        vm.warp(block.timestamp + 5 days);
        uint256 redeemAmountOut = bonds.redeemBond(alice, 0);

        uint256 balAfter = MockERC20(output).balanceOf(alice);

        assertEq(redeemAmountOut, expectedAmountOut);
        assertEq(balAfter, balBefore + redeemAmountOut);
    }

    function testBondRedemptionPartial() public {
        address alice = address(0xAAAA);
        uint256 expectedAmountOut = 99900099900099900 >> 1;

        deal(address(output), address(bonds), 100 ether);
        deal(address(input), alice, 1 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        vm.startPrank(alice);
        MockERC20(input).approve(address(bonds), 1 ether);

        uint256 balBefore = MockERC20(output).balanceOf(alice);
        bonds.purchaseBond(alice, 1 ether, 0);

        vm.warp(block.timestamp + 2.5 days);

        uint256 redeemAmountOut = bonds.redeemBond(address(this), 0);
        uint256 balAfter = MockERC20(output).balanceOf(address(this));

        assertEq(redeemAmountOut, expectedAmountOut);
        assertEq(balAfter, balBefore + redeemAmountOut);

        vm.warp(block.timestamp + 2.5 days);

        // redeem second half

        balBefore = MockERC20(output).balanceOf(address(this));
        redeemAmountOut = bonds.redeemBond(address(this), 0);
        balAfter = MockERC20(output).balanceOf(address(this));

        assertEq(balAfter, balBefore + redeemAmountOut);
        assertEq(redeemAmountOut, expectedAmountOut);
    }

    function testBondRedemptionFullMultipleUsers() public {
        uint256 expectedAmountOutAlice = 99900099900099900;
        uint256 expectedAmountOutBob = 99700698503093712;

        // setup test accounts
        address alice = address(0xAAAA);
        address bob = address(0xBBBB);

        deal(address(output), address(bonds), 100 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(10_000);
        bonds.setLastUpdate();
        bonds.setPause();

        // 1) Alice decides to spend 1 input on 0.099900099900099910 output
        vm.startPrank(alice);
        MockERC20(input).mint(alice, 1e18);
        MockERC20(input).approve(address(bonds), 1e18);
        uint256 aliceAmountOut = bonds.purchaseBond(alice, 1e18, 0);
        vm.stopPrank();

        // 2) 1 hour 30 minutes later Bob decides to spending 1 input on 0.099700698503093712 output
        vm.warp(block.timestamp + 1.5 hours);
        vm.startPrank(bob);
        MockERC20(input).mint(bob, 1e18);
        MockERC20(input).approve(address(bonds), 1e18);
        uint256 bobAmountOut = bonds.purchaseBond(bob, 1e18, 0);
        vm.stopPrank();

        // 3) 22 hours 30 mins later Alice decides to redeem available payout 99900099900099900 / 5
        vm.warp(block.timestamp + 22.5 hours);
        vm.startPrank(alice);
        uint256 aliceRedeemAmountOut1 = bonds.redeemBond(alice, 0);
        vm.stopPrank();

        assertEq(aliceAmountOut, expectedAmountOutAlice);
        assertEq(bobAmountOut, expectedAmountOutBob);
        assertEq(aliceRedeemAmountOut1, expectedAmountOutAlice / 5);
    }

    function testBondTransfer() public {
        uint256 expectedAmountOut = 99900099900099900;

        deal(address(output), address(bonds), 100 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(1 days);
        bonds.setLevelBips(10_000);
        bonds.setLastUpdate();
        bonds.setPause();

        MockERC20(input).mint(address(this), 1e18);
        MockERC20(input).approve(address(bonds), 1e18);

        uint256 amountOut = bonds.purchaseBond(address(this), 1e18, 0);
        (uint256 owed, uint256 redeemed, uint256 creation) = bonds.bondOf(address(this), 0);

        assertEq(amountOut, expectedAmountOut);
        assertEq(owed, expectedAmountOut);
        assertEq(redeemed, 0);
        assertEq(creation, block.timestamp);

        bonds.transferBond(address(1), 0);

        (owed, redeemed, creation) = bonds.bondOf(address(1), 0);

        assertEq(owed, expectedAmountOut);
        assertEq(redeemed, 0);
        assertEq(creation, block.timestamp);

        (owed, redeemed, creation) = bonds.bondOf(address(this), 0);

        assertEq(owed, 0);
        assertEq(redeemed, 0);
        assertEq(creation, 0);
    }
}
