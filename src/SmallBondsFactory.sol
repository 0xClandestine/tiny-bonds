// SPDX-License-Identifier: WTFPL
pragma solidity >=0.8.0;

import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";
import {LibClone} from "solbase/utils/LibClone.sol";
import {SmallBonds} from "./SmallBonds.sol";

/// @notice Creates clones of SmallBonds with immutable args.
/// @author 0xClandestine
contract SmallBondsFactory is SafeMulticallable {
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

    /// @dev Use a multicall if you'd like to create multiple markets in a single call.
    function create(bytes32 salt, address outputToken, address inputToken, uint256 term)
        external
        returns (address market)
    {
        bytes memory data = abi.encode(outputToken, inputToken, term);

        market = implementation.cloneDeterministic(data, salt);

        emit MarketCreated(market);
    }

    function predictDeterministicAddress(bytes32 salt, address outputToken, address inputToken, uint256 term)
        external
        view
        returns (address)
    {
        bytes memory data = abi.encode(outputToken, inputToken, term);

        return implementation.predictDeterministicAddress(data, salt, address(this));
    }
}
