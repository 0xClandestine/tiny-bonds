// SPDX-License-Identifier: WTFPL
pragma solidity >=0.8.0;

import {LibClone} from "solbase/utils/LibClone.sol";
import {SmallBonds} from "./SmallBonds.sol";

/// @notice Creates clones of SmallBonds with immutable args. 
/// @author 0xClandestine
contract SmallBondsFactory {

    /// -----------------------------------------------------------------------
    /// Dependencies
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event MarketCreated(address market);

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    address public immutable implementation;

    constructor() {
        implementation = address(new SmallBonds());
    }

    /// -----------------------------------------------------------------------
    /// Factory Logic
    /// -----------------------------------------------------------------------

    function create(
        address outputToken,
        address inputToken,
        uint256 term
    ) external returns (address market) {

        bytes memory data = abi.encode(outputToken, inputToken, term);

        market = implementation.cloneDeterministic(data, keccak256(data));

        emit MarketCreated(market);
    }

    function predictDeterministicAddress(
        address outputToken,
        address inputToken,
        uint256 term
    ) external view returns (address) {

        bytes memory data = abi.encode(outputToken, inputToken, term);

        return implementation.predictDeterministicAddress(data, keccak256(data), address(this));
    }
}