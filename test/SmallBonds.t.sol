// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SmallBondsFactory.sol";
import "solbase/tokens/ERC20/ERC20.sol";

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
    }

    function testCreate() public {
        uint256 term = 5 days;
        
        address outputAddress = factory.create(output, input, term);

        address predictedAddress = factory.predictDeterministicAddress(output, input, term);
        
        SmallBonds(outputAddress).initialize(address(this));

        assertEq(outputAddress, predictedAddress);
        assertEq(SmallBonds(outputAddress).term(), 5 days);
        assertEq(SmallBonds(outputAddress).outputToken(), output);
        assertEq(SmallBonds(outputAddress).inputToken(), input);
        assertEq(SmallBonds(outputAddress).owner(), address(this));
    }
}