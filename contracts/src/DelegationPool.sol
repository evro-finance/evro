// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/IDelegationPool.sol";

/**
 * @title DelegationPool
 * @notice A pool that can receive ERC20 tokens and delegate spending authority to a delegatee
 *         (troveOpener) without allowing the delegatee to directly transfer tokens out.
 * @dev The delegatee can be approved to spend tokens (e.g., for BorrowerOperations),
 *      but cannot directly call transfer/transferFrom on tokens held by this pool.
 */
contract DelegationPool is IDelegationPool {
    using SafeERC20 for IERC20;

    /// @notice The address that can be delegated tokens (typically BorrowerOperations)
    address public immutable delegatee;
    
    /// @notice The ERC20 collateral token this pool holds
    address public immutable collateralToken;

    /// @notice The address of the active pool
    address public immutable activePool;

    /**
     * @notice Initialize the DelegationPool with a delegatee and collateral token
     * @param _delegatee The address that can be delegated tokens (troveOpener)
     * @param _collateralToken The ERC20 token address this pool will hold
     */
    constructor(address _delegatee, address _collateralToken, address _activePool) {
        require(_delegatee != address(0), "DelegationPool: zero delegatee");
        require(_collateralToken != address(0), "DelegationPool: zero collateral token");
        
        delegatee = _delegatee;
        collateralToken = _collateralToken;
        activePool = _activePool;
    }

    /**
     * @notice Get the current balance of collateral tokens held by this pool
     * @return The balance of collateral tokens
     */
    function balance() external view returns (uint256) {
        return IERC20(collateralToken).balanceOf(address(this));
    }

    function sendColl(address _to, uint256 _amount) external {
        require(msg.sender == activePool, "DelegationPool: only active pool can send tokens.");
        IERC20(collateralToken).safeTransfer(_to, _amount);
    }

    function delegateCollateral() external {
        //TODO: delegate collateral with ERC-712 signature to delegatee
    }
}
