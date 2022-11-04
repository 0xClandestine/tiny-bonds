// SPDX-License-Identifier: WTFPL
pragma solidity >=0.8.0;

import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";
import {LibClone} from "solbase/utils/LibClone.sol";
import {TinyBonds} from "./TinyBonds.sol";

/// @notice Creates clones of TinyBonds with immutable args.
/// @author 0xClandestine
contract TinyBondsFactory is SafeMulticallable {
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
        implementation = address(new TinyBonds());
    }

    /// -----------------------------------------------------------------------
    /// Factory Logic
    /// -----------------------------------------------------------------------

    /// @dev Use a multicall if you'd like to create multiple markets in a single call.
    function create(bytes32 salt, address outputToken, address inputToken, uint256 term)
        external
        returns (address market)
    {
        market = implementation.cloneDeterministic(abi.encode(outputToken, inputToken, term), salt);

        emit MarketCreated(market);
    }

    function predictDeterministicAddress(bytes32 salt, address outputToken, address inputToken, uint256 term)
        external
        view
        returns (address)
    {
        return implementation.predictDeterministicAddress(
            abi.encode(outputToken, inputToken, term), salt, address(this)
        );
    }
}
