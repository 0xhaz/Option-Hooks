// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Access, AccessControl} from "src/Access.sol";
import {Option, EnumerableSet} from "src/Option.sol";

contract VolumeTrackerHook is BaseHook, Access, Option {
    using EnumerableSet for EnumerableSet.UintSet;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    // Note: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------
    uint256 public constant DIVIDE_FACTOR = 1000;
    uint256 public factor;
    address public developer;
    uint256 public min = 12; // the minimum is 1.2
    uint256 public max = 32; // the maximum is 3.2
    // if the liquidity is greater than the threshold, the strike corresponds to the min
    uint256 public threshold = 100 ether;
    address public immutable OK;

    PoolId public immutable id;

    mapping(address user => uint256 swapAmount) public afterSwapCount;

    constructor(IPoolManager _poolManager, string memory _uri, uint256 _ratio, address _okb, address _admin)
        BaseHook(_poolManager)
        Access(_admin)
        Option(_uri)
    {
        factor = _ratio;
        OK = _okb;
        id = PoolKey(Currency.wrap(address(0)), Currency.wrap(address(_okb)), 3000, 60, IHooks(address(this))).toId();
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookdata
    ) external override returns (bytes4, int128) {
        // The address which should receive the option be set as an input in hookdata
        address user = abi.decode(hookdata, (address));

        if (Currency.wrap(address(0)) < Currency.wrap(OK)) {
            // If this is not an ETH-OKB pool with this hook attached, ignore
            if (!key.currency0.isNative() && Currency.unwrap(key.currency1) != OK) return (this.afterSwap.selector, 0);

            // We only consider swaps in one direction (in our case when user buys OKB)
            if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);
        } else {
            // If this is not an OKB-ETH pool with this hook attached, ignore
            if (!key.currency1.isNative() && Currency.unwrap(key.currency0) != OK) return (this.afterSwap.selector, 0);

            // We only consider swaps in one direction (in our case when user buys OKB
            if (swapParams.zeroForOne) return (this.afterSwap.selector, 0);
        }

        // if amountSpecified < 0;
        //    this is an "exact input for output" swap
        //    amount of tokens they spent is equal to [amountSpecified]
        // if amountSpecified > 0;
        //    this is an "exact output for input" swap
        //    amount of tokens they spent is equal to BalanceDelta.amount0()
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, Option) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
