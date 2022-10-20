// SPDX-License-Identifier: WTFPL
pragma solidity >=0.8.0;

import {Owned} from "solbase/auth/Owned.sol";
import {ERC20} from "solbase/tokens/ERC20/ERC20.sol";
import {FixedPointMathLib} from "solbase/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solbase/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solbase/utils/SafeCastLib.sol";
import {SafeMulticallable} from "solbase/utils/SafeMulticallable.sol";
import {SelfPermit} from "solbase/utils/SelfPermit.sol";
import {Clone} from "solbase/utils/Clone.sol";

struct Bond {
    uint256 owed;
    uint256 redeemed;
    uint256 creation;
}

// 2 slots, 64 bytes
struct Pricing {
    uint128 virtualInputReserves; // 16 bytes
    uint128 virtualOutputReserves; // 16 bytes
    uint64 lastUpdate; // 8 bytes
    uint96 halfLife; // 12 bytes
    uint96 levelBips; // 12 bytes
}

/// @title SmallBonds
/// @author 0xClandestine
contract SmallBonds is Owned(address(0)), SafeMulticallable, SelfPermit, Clone {
    /// -----------------------------------------------------------------------
    /// Dependencies
    /// -----------------------------------------------------------------------

    using SafeTransferLib for address;

    using FixedPointMathLib for uint256;

    using SafeCastLib for uint256;

    using SafeCastLib for uint128;

    using SafeCastLib for uint64;

    /// -----------------------------------------------------------------------
    /// Bond Events
    /// -----------------------------------------------------------------------

    event BondSold(address indexed bonder, uint256 amountIn, uint256 output);

    event BondRedeemed(address indexed bonder, uint256 indexed bondId, uint256 output);

    event BondTransfered(address indexed sender, address indexed to, uint256 senderBondId, uint256 recipientBondId);

    /// -----------------------------------------------------------------------
    /// Management Events
    /// -----------------------------------------------------------------------

    event VirtualInputReservesSet(uint256 newValue);

    event VirtualOutputReservesSet(uint256 newValue);

    event HalfLifeSet(uint256 newValue);

    event LevelBipsSet(uint256 newValue);

    event LastUpdateSet(uint256 newValue);

    event Paused(bool paused);

    /// -----------------------------------------------------------------------
    /// Mutables
    /// -----------------------------------------------------------------------

    bool public paused;

    bool public initialized;

    uint256 public totalDebt;

    Pricing public pricing;

    mapping(address => Bond[]) public bondOf;

    /// -----------------------------------------------------------------------
    /// Immutables
    /// -----------------------------------------------------------------------

    function term() public pure returns (uint256) {
        return _getArgUint256(0);
    }

    function inputToken() public pure returns (address) {
        return _getArgAddress(32);
    }

    function outputToken() public pure returns (address) {
        return _getArgAddress(52);
    }

    function initialize(address _owner) external {
        require(!initialized, "INITIALIZED");
        owner = _owner;
        initialized = true;
        paused = true;
        emit Paused(true);
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier whenNotPaused() {
        require(!paused, "PAUSED");
        _;
    }

    /// -----------------------------------------------------------------------
    /// Bond Purchase Logic
    /// -----------------------------------------------------------------------

    function purchaseBond(address to, uint256 amountIn, uint256 minOutput) external virtual returns (uint256 output) {
        Pricing storage info = pricing;
        require(info.virtualInputReserves != 0, "!LIQUIDITY");
        uint256 _availableDebt = availableDebt();
        output = getAmountOut(
            amountIn,
            _availableDebt,
            info.virtualOutputReserves,
            info.virtualInputReserves,
            block.timestamp - info.lastUpdate,
            info.halfLife,
            info.levelBips
        );
        require(output >= minOutput && _availableDebt >= output, "BAD OUTPUT");
        inputToken().safeTransferFrom(msg.sender, owner, amountIn);
        unchecked {
            totalDebt += output;
        }
        info.virtualInputReserves += amountIn.safeCastTo128();
        bondOf[to].push(Bond(output, 0, block.timestamp));
        emit BondSold(msg.sender, amountIn, output);
    }

    /// -----------------------------------------------------------------------
    /// Bond Redemption Logic
    /// -----------------------------------------------------------------------

    function redeemBond(address to, uint256 bondId) external whenNotPaused returns (uint256 output) {
        Bond storage position = bondOf[msg.sender][bondId];
        output = getRedeemAmountOut(position.owed, position.redeemed, position.creation);
        if (output > 0) {
            totalDebt -= output;
            position.redeemed += output;
            outputToken().safeTransfer(to, output);
            emit BondRedeemed(msg.sender, bondId, output);
        }
        require(output > 0, "!OUTPUT");
    }

    function redeemBondBatch(address to, uint256[] memory bondIds)
        external
        virtual
        whenNotPaused
        returns (uint256 totalOutput)
    {
        uint256 length = bondIds.length;
        for (uint256 i; i < length;) {
            Bond storage position = bondOf[msg.sender][bondIds[i]];
            uint256 output = getRedeemAmountOut(position.owed, position.redeemed, position.creation);
            position.redeemed += output;
            totalOutput += output;
            emit BondRedeemed(msg.sender, bondIds[i], output);
            unchecked {
                i++;
            }
        }
        totalDebt -= totalOutput;
        outputToken().safeTransfer(to, totalOutput);
    }

    /// -----------------------------------------------------------------------
    /// Bond Transfer Logic
    /// -----------------------------------------------------------------------

    function transferBond(address to, uint256 bondId) external whenNotPaused {
        Bond memory position = bondOf[msg.sender][bondId];
        delete bondOf[msg.sender][bondId];
        bondOf[to].push(position);
        emit BondTransfered(msg.sender, to, bondId, bondOf[to].length);
    }

    /// -----------------------------------------------------------------------
    /// Bond Management Logic
    /// -----------------------------------------------------------------------

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setVirtualInputReserves(uint128 newValue) external onlyOwner {
        Pricing storage info = pricing;
        info.virtualInputReserves = newValue;
        emit VirtualInputReservesSet(newValue);
    }

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setVirtualOutputReserves(uint128 newValue) external onlyOwner {
        Pricing storage info = pricing;
        info.virtualOutputReserves = newValue;
        emit VirtualOutputReservesSet(newValue);
    }

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setHalfLife(uint96 newValue) external onlyOwner {
        Pricing storage info = pricing;
        info.halfLife = newValue;
        emit HalfLifeSet(newValue);
    }

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setLevelBips(uint96 newValue) external onlyOwner {
        Pricing storage info = pricing;
        info.levelBips = newValue;
        emit LevelBipsSet(newValue);
    }

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setLastUpdate() external onlyOwner {
        Pricing storage info = pricing;
        info.lastUpdate = (block.timestamp).safeCastTo64();
        emit LastUpdateSet(block.timestamp);
    }

    /// @dev Warning: you should either pause the contract before modifications, or use a multicall.
    function setPause() external onlyOwner {
        bool newValue = !paused;
        paused = newValue;
        emit Paused(newValue);
    }

    /// -----------------------------------------------------------------------
    /// Viewables
    /// -----------------------------------------------------------------------

    /// @dev Returns value that accounts for price decay.
    function virtualInputReverves() external view returns (uint256) {
        Pricing memory info = pricing;
        return expToLevel(info.virtualInputReserves, block.timestamp - info.lastUpdate, info.halfLife, info.levelBips);
    }

    function positionCountOf(address account) external view returns (uint256) {
        return bondOf[account].length;
    }

    function availableDebt() public view returns (uint256) {
        return ERC20(outputToken()).balanceOf(address(this)) - totalDebt;
    }

    function spotPriceFor() external view returns (uint256) {
        Pricing memory info = pricing;

        uint256 virtualInputReserves =
            expToLevel(info.virtualInputReserves, block.timestamp - info.lastUpdate, info.halfLife, info.levelBips);

        return FixedPointMathLib.mulDivDown(1e18, virtualInputReserves, availableDebt() + info.virtualOutputReserves);
    }

    function getAmountOut(uint256 amountIn) external view returns (uint256 output) {
        Pricing memory info = pricing;

        output = getAmountOut(
            amountIn,
            availableDebt(),
            info.virtualOutputReserves,
            info.virtualInputReserves,
            block.timestamp - info.lastUpdate,
            info.halfLife,
            info.levelBips
        );
    }

    /// -----------------------------------------------------------------------
    /// Internal Helpers
    /// -----------------------------------------------------------------------

    function getRedeemAmountOut(uint256 owed, uint256 redeemed, uint256 creation) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - creation;
        if (elapsed > term()) elapsed = term();
        return owed.mulDivDown(elapsed, term()) - redeemed;
    }

    function getAmountOut(
        uint256 input,
        uint256 outputReserves,
        uint256 virtualOutputAmt,
        uint256 virtualInputAmt,
        uint256 elapsed,
        uint256 halfLife,
        uint256 levelBips
    ) internal pure returns (uint256 output) {
        output = input.mulDivDown(
            outputReserves + virtualOutputAmt, expToLevel(virtualInputAmt, elapsed, halfLife, levelBips) + input
        );
    }

    function expToLevel(uint256 x, uint256 elapsed, uint256 halfLife, uint256 levelBips)
        internal
        pure
        returns (uint256 z)
    {
        z = x >> (elapsed / halfLife);
        z -= z.mulDivDown(elapsed % halfLife, halfLife) >> 1;
        z += (x - z).mulDivDown(levelBips, 1e4);
    }
}
