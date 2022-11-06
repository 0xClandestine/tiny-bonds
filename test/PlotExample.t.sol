// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solplot/Plot.sol";
import "solbase/tokens/ERC20/ERC20.sol";

import "../src/TinyBondsFactory.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("", "", 18) {}

    function mint(address guy, uint256 wad) public {
        _mint(guy, wad);
    }
}

contract PlotExample is Plot {

    TinyBondsFactory factory;
    TinyBonds bonds;
    address input; // give
    address output; // want

    function setUp() public {
        factory = new TinyBondsFactory();
        input = address(new MockERC20());
        output = address(new MockERC20());
        bonds = TinyBonds(factory.create(keccak256(abi.encode(420)), output, input, 5 days));
    }

    // idea add decay on positive bias
    function testPlotSinglePurchase() public {

        vm.removeFile("output.svg");
        vm.warp(1000);

        address alice = address(0xAAAA);

        deal(address(output), address(bonds), 100 ether);
        deal(address(input), alice, 10 ether);

        bonds.initialize(address(this));
        bonds.setVirtualInputReserves(1000 ether);
        bonds.setHalfLife(10);
        bonds.setLevelBips(9_000);
        bonds.setLastUpdate();
        bonds.setPause();

        vm.prank(alice);
        MockERC20(input).approve(address(bonds), 10 ether);


        for (uint256 i; i < 100; i++) {

            vm.warp(1000 + i);

            if (i == 75) {
                vm.prank(alice);
                uint256 amountOut = bonds.purchaseBond(alice, 10 ether, 0);
            }

            vm.writeLine("input.txt", vm.toString(bonds.spotPrice()));
        }

        plot("input.txt", "output.svg", "cyan");

        vm.removeFile("input.txt");
    }
}
