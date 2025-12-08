// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "./DelegationPool.sol";
import "./Interfaces/IDelegationPool.sol";

/**
 * @title DelegationPoolFactory
 * @notice Factory contract for creating DelegationPool instances
 * @dev Each DelegationPool is created with a specific delegatee (troveOpener) and collateral token
 */
contract DelegationPoolFactory {
    /// @notice Event emitted when a new DelegationPool is created
    event DelegationPoolCreated(
        address indexed pool,
        address indexed delegatee,
        address indexed collateralToken,
        address activePool
    );

    /// @notice Mapping to track created pools: (delegatee, collateralToken) => pool address
    mapping(address => mapping(address => address)) public pools;

    /**
     * @notice Create a new DelegationPool for a given delegatee and collateral token
     * @param _delegatee The address that can be delegated tokens (troveOpener, typically BorrowerOperations)
     * @param _collateralToken The ERC20 token address this pool will hold
     * @param _activePool The address of the ActivePool that can send tokens from this pool
     * @return pool The address of the newly created DelegationPool
     */
    function createDelegationPool(
        address _delegatee,
        address _collateralToken,
        address _activePool
    ) external returns (address pool) {
        require(_delegatee != address(0), "DelegationPoolFactory: zero delegatee");
        require(_collateralToken != address(0), "DelegationPoolFactory: zero collateral token");
        require(_activePool != address(0), "DelegationPoolFactory: zero active pool");
        
        // Check if pool already exists
        require(
            pools[_delegatee][_collateralToken] == address(0),
            "DelegationPoolFactory: pool already exists"
        );

        // Deploy new DelegationPool
        pool = address(new DelegationPool(_delegatee, _collateralToken, _activePool));
        
        // Store the pool address
        pools[_delegatee][_collateralToken] = pool;

        emit DelegationPoolCreated(pool, _delegatee, _collateralToken, _activePool);

        return pool;
    }

    /**
     * @notice Get the address of an existing DelegationPool
     * @param _delegatee The delegatee address
     * @param _collateralToken The collateral token address
     * @return The address of the DelegationPool, or address(0) if it doesn't exist
     */
    function getDelegationPool(
        address _delegatee,
        address _collateralToken
    ) external view returns (address) {
        return pools[_delegatee][_collateralToken];
    }
}

