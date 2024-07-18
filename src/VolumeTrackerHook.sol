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
    {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, Option) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
