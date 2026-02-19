// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./Interfaces/ITroveManager.sol";
import "./Interfaces/IEvroToken.sol";
import "./Dependencies/Constants.sol";
import "./Dependencies/LiquityMath.sol";

import "./Interfaces/ICollateralRegistry.sol";

import "./Dependencies/Ownable.sol";

contract CollateralRegistry is ICollateralRegistry, Ownable {
    // See: https://github.com/ethereum/solidity/issues/12587
    // uint256 public immutable totalCollaterals;

    // IERC20Metadata internal immutable token0;
    // IERC20Metadata internal immutable token1;
    // IERC20Metadata internal immutable token2;
    // IERC20Metadata internal immutable token3;
    // IERC20Metadata internal immutable token4;
    // IERC20Metadata internal immutable token5;
    // IERC20Metadata internal immutable token6;
    // IERC20Metadata internal immutable token7;
    // IERC20Metadata internal immutable token8;
    // IERC20Metadata internal immutable token9;
    IERC20Metadata[] public tokens;
    ITroveManager[] public troveManagers;

    IEvroToken public immutable evroToken;

    uint256 public baseRate;
    address public collateralGovernor;

    // The timestamp of the latest fee operation (redemption or new Evro issuance)
    uint256 public lastFeeOperationTime = block.timestamp;

    event BaseRateUpdated(uint256 _baseRate);
    event LastFeeOpTimeUpdated(uint256 _lastFeeOpTime);
    event CollateralGovernorUpdated(address _collateralGovernor);
    event NewBranchAdded(IERC20Metadata _token, ITroveManager _troveManager);
    constructor(IEvroToken _evroToken, IERC20Metadata[] memory _tokens, ITroveManager[] memory _troveManagers, address _governor, address _collateralGovernor) Ownable(_governor) {
        require(_evroToken != IEvroToken(address(0)), "Evro token cannot be zero address");
        require(_tokens.length > 0, "Collateral list cannot be empty");
        require(_troveManagers.length > 0, "Trove manager list cannot be empty");
        require(_collateralGovernor != address(0), "Collateral governor cannot be zero address");

        uint256 numTokens = _tokens.length;
        require(numTokens > 0, "Collateral list cannot be empty");
        require(numTokens <= 10, "Collateral list too long");
        // totalCollaterals = numTokens;

        evroToken = _evroToken;

        // token0 = _tokens[0];
        // token1 = numTokens > 1 ? _tokens[1] : IERC20Metadata(address(0));
        // token2 = numTokens > 2 ? _tokens[2] : IERC20Metadata(address(0));
        // token3 = numTokens > 3 ? _tokens[3] : IERC20Metadata(address(0));
        // token4 = numTokens > 4 ? _tokens[4] : IERC20Metadata(address(0));
        // token5 = numTokens > 5 ? _tokens[5] : IERC20Metadata(address(0));
        // token6 = numTokens > 6 ? _tokens[6] : IERC20Metadata(address(0));
        // token7 = numTokens > 7 ? _tokens[7] : IERC20Metadata(address(0));
        // token8 = numTokens > 8 ? _tokens[8] : IERC20Metadata(address(0));
        // token9 = numTokens > 9 ? _tokens[9] : IERC20Metadata(address(0));

        // troveManager0 = _troveManagers[0];
        // troveManager1 = numTokens > 1 ? _troveManagers[1] : ITroveManager(address(0));
        // troveManager2 = numTokens > 2 ? _troveManagers[2] : ITroveManager(address(0));
        // troveManager3 = numTokens > 3 ? _troveManagers[3] : ITroveManager(address(0));
        // troveManager4 = numTokens > 4 ? _troveManagers[4] : ITroveManager(address(0));
        // troveManager5 = numTokens > 5 ? _troveManagers[5] : ITroveManager(address(0));
        // troveManager6 = numTokens > 6 ? _troveManagers[6] : ITroveManager(address(0));
        // troveManager7 = numTokens > 7 ? _troveManagers[7] : ITroveManager(address(0));
        // troveManager8 = numTokens > 8 ? _troveManagers[8] : ITroveManager(address(0));
        // troveManager9 = numTokens > 9 ? _troveManagers[9] : ITroveManager(address(0));

        for (uint256 i = 0; i < numTokens; i++) {
            tokens.push(_tokens[i]);
            troveManagers.push(_troveManagers[i]);
        }

        // Initialize the baseRate state variable
        baseRate = INITIAL_BASE_RATE;
        emit BaseRateUpdated(INITIAL_BASE_RATE);

        collateralGovernor = _collateralGovernor;
        emit CollateralGovernorUpdated(_collateralGovernor);
    }

    struct RedemptionTotals {
        uint256 numCollaterals;
        uint256 evroSupplyAtStart;
        uint256 unbacked;
        uint256 redeemedAmount;
    }

    function redeemCollateral(uint256 _evroAmount, uint256 _maxIterationsPerCollateral, uint256 _maxFeePercentage)
        external
    {
        _requireValidMaxFeePercentage(_maxFeePercentage);
        _requireAmountGreaterThanZero(_evroAmount);

        RedemptionTotals memory totals;

        totals.numCollaterals = totalCollaterals();
        uint256[] memory unbackedPortions = new uint256[](totals.numCollaterals);
        uint256[] memory prices = new uint256[](totals.numCollaterals);

        // Gather and accumulate unbacked portions
        for (uint256 index = 0; index < totals.numCollaterals; index++) {
            ITroveManager troveManager = getTroveManager(index);
            (uint256 unbackedPortion, uint256 price, bool redeemable) =
                troveManager.getUnbackedPortionPriceAndRedeemability();
            prices[index] = price;
            if (redeemable) {
                totals.unbacked += unbackedPortion;
                unbackedPortions[index] = unbackedPortion;
            }
        }

        // There’s an unlikely scenario where all the normally redeemable branches (i.e. having TCR > SCR) have 0 unbacked
        // In that case, we redeem proportionally to branch size
        if (totals.unbacked == 0) {
            unbackedPortions = new uint256[](totals.numCollaterals);
            for (uint256 index = 0; index < totals.numCollaterals; index++) {
                ITroveManager troveManager = getTroveManager(index);
                (,, bool redeemable) = troveManager.getUnbackedPortionPriceAndRedeemability();
                if (redeemable) {
                    uint256 unbackedPortion = troveManager.getEntireBranchDebt();
                    totals.unbacked += unbackedPortion;
                    unbackedPortions[index] = unbackedPortion;
                }
            }
        } else {
            // Don't allow redeeming more than the total unbacked in one go, as that would result in a disproportionate
            // redemption (see CS-BOLD-013). Instead, truncate the redemption to total unbacked. If this happens, the
            // redeemer can call `redeemCollateral()` a second time to redeem the remainder of their BOLD.
            if (_evroAmount > totals.unbacked) {
                _evroAmount = totals.unbacked;
            }
        }

        totals.evroSupplyAtStart = evroToken.totalSupply();
        // Decay the baseRate due to time passed, and then increase it according to the size of this redemption.
        // Use the saved total Evro supply value, from before it was reduced by the redemption.
        // We only compute it here, and update it at the end,
        // because the final redeemed amount may be less than the requested amount
        // Redeemers should take this into account in order to request the optimal amount to not overpay
        uint256 redemptionRate =
            _calcRedemptionRate(_getUpdatedBaseRateFromRedemption(_evroAmount, totals.evroSupplyAtStart));
        require(redemptionRate <= _maxFeePercentage, "CR: Fee exceeded provided maximum");
        // Implicit by the above and the _requireValidMaxFeePercentage checks
        //require(newBaseRate < DECIMAL_PRECISION, "CR: Fee would eat up all collateral");

        // Compute redemption amount for each collateral and redeem against the corresponding TroveManager
        for (uint256 index = 0; index < totals.numCollaterals; index++) {
            //uint256 unbackedPortion = unbackedPortions[index];
            if (unbackedPortions[index] > 0) {
                uint256 redeemAmount = _evroAmount * unbackedPortions[index] / totals.unbacked;
                if (redeemAmount > 0) {
                    ITroveManager troveManager = getTroveManager(index);
                    uint256 redeemedAmount = troveManager.redeemCollateral(
                        msg.sender, redeemAmount, prices[index], redemptionRate, _maxIterationsPerCollateral
                    );
                    totals.redeemedAmount += redeemedAmount;
                }

                // Ensure that per-branch redeems add up to `_evroAmount` exactly
                _evroAmount -= redeemAmount;
                totals.unbacked -= unbackedPortions[index];
            }
        }

        _updateBaseRateAndGetRedemptionRate(totals.redeemedAmount, totals.evroSupplyAtStart);

        // Burn the total Evro that is cancelled with debt
        if (totals.redeemedAmount > 0) {
            evroToken.burn(msg.sender, totals.redeemedAmount);
        }
    }

    // --- Internal fee functions ---

    // Update the last fee operation time only if time passed >= decay interval. This prevents base rate griefing.
    function _updateLastFeeOpTime() internal {
        uint256 minutesPassed = _minutesPassedSinceLastFeeOp();

        if (minutesPassed > 0) {
            lastFeeOperationTime += ONE_MINUTE * minutesPassed;
            emit LastFeeOpTimeUpdated(lastFeeOperationTime);
        }
    }

    function _minutesPassedSinceLastFeeOp() internal view returns (uint256) {
        return (block.timestamp - lastFeeOperationTime) / ONE_MINUTE;
    }

    // Updates the `baseRate` state with math from `_getUpdatedBaseRateFromRedemption`
    function _updateBaseRateAndGetRedemptionRate(uint256 _evroAmount, uint256 _totalEvroSupplyAtStart) internal {
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_evroAmount, _totalEvroSupplyAtStart);

        //assert(newBaseRate <= DECIMAL_PRECISION); // This is already enforced in `_getUpdatedBaseRateFromRedemption`

        // Update the baseRate state variable
        baseRate = newBaseRate;
        emit BaseRateUpdated(newBaseRate);

        _updateLastFeeOpTime();
    }

    /*
     * This function calculates the new baseRate in the following way:
     * 1) decays the baseRate based on time passed since last redemption or Evro borrowing operation.
     * then,
     * 2) increases the baseRate based on the amount redeemed, as a proportion of total supply
     */
    function _getUpdatedBaseRateFromRedemption(uint256 _redeemAmount, uint256 _totalEvroSupply)
        internal
        view
        returns (uint256)
    {
        // decay the base rate
        uint256 decayedBaseRate = _calcDecayedBaseRate();

        // get the fraction of total supply that was redeemed
        uint256 redeemedEvroFraction = _redeemAmount * DECIMAL_PRECISION / _totalEvroSupply;

        uint256 newBaseRate = decayedBaseRate + redeemedEvroFraction / REDEMPTION_BETA;
        newBaseRate = LiquityMath._min(newBaseRate, DECIMAL_PRECISION); // cap baseRate at a maximum of 100%

        return newBaseRate;
    }

    function _calcDecayedBaseRate() internal view returns (uint256) {
        uint256 minutesPassed = _minutesPassedSinceLastFeeOp();
        uint256 decayFactor = LiquityMath._decPow(REDEMPTION_MINUTE_DECAY_FACTOR, minutesPassed);

        return baseRate * decayFactor / DECIMAL_PRECISION;
    }

    function _calcRedemptionRate(uint256 _baseRate) internal pure returns (uint256) {
        return LiquityMath._min(
            REDEMPTION_FEE_FLOOR + _baseRate,
            DECIMAL_PRECISION // cap at a maximum of 100%
        );
    }

    function _calcRedemptionFee(uint256 _redemptionRate, uint256 _amount) internal pure returns (uint256) {
        uint256 redemptionFee = _redemptionRate * _amount / DECIMAL_PRECISION;
        return redemptionFee;
    }

    // external redemption rate/fee getters

    function getRedemptionRate() external view override returns (uint256) {
        return _calcRedemptionRate(baseRate);
    }

    function getRedemptionRateWithDecay() public view override returns (uint256) {
        return _calcRedemptionRate(_calcDecayedBaseRate());
    }

    function getRedemptionRateForRedeemedAmount(uint256 _redeemAmount) external view returns (uint256) {
        uint256 totalEvroSupply = evroToken.totalSupply();
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_redeemAmount, totalEvroSupply);
        return _calcRedemptionRate(newBaseRate);
    }

    function getRedemptionFeeWithDecay(uint256 _ETHDrawn) external view override returns (uint256) {
        return _calcRedemptionFee(getRedemptionRateWithDecay(), _ETHDrawn);
    }

    function getEffectiveRedemptionFeeInEvro(uint256 _redeemAmount) external view override returns (uint256) {
        uint256 totalEvroSupply = evroToken.totalSupply();
        uint256 newBaseRate = _getUpdatedBaseRateFromRedemption(_redeemAmount, totalEvroSupply);
        return _calcRedemptionFee(_calcRedemptionRate(newBaseRate), _redeemAmount);
    }

    function totalCollaterals() public view override returns (uint256) {
        return tokens.length;
    }

    // getters

    function getToken(uint256 _index) external view returns (IERC20Metadata) {
 return tokens[_index];
    }

    function getTroveManager(uint256 _index) public view returns (ITroveManager) {
 return troveManagers[_index];
    }

    // require functions

    function _requireValidMaxFeePercentage(uint256 _maxFeePercentage) internal pure {
        require(
            _maxFeePercentage >= REDEMPTION_FEE_FLOOR && _maxFeePercentage <= DECIMAL_PRECISION,
            "Max fee percentage must be between 0.5% and 100%"
        );
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        require(_amount > 0, "CollateralRegistry: Amount must be greater than zero");
    }

      /*
    @notice Creates a new branch for the collateral registry
    @param _token The collateral token for the new branch
    @param _troveManager The trove manager for the new branch
    @param _isRedeemable Whether the new branch is redeemable

    @dev If the new branch is redeemable, it will be added to the redeemable branches array, but only 10 are allowed
    Alos, make sure that is doesnt already exist. Do not add a new branch using an existing known trove manager. Governor is exxpected to be trusted on this.
    */
    function createNewBranch(IERC20Metadata _token, ITroveManager _troveManager) external {
        require(msg.sender == collateralGovernor, "CR: Only collateral governor can create new branches");


        address _stabilityPool = address(_troveManager.stabilityPool());
        address _borrowerOperations = address(_troveManager.borrowerOperations());
        address _activePool = address(_troveManager.activePool());

        require(_stabilityPool != address(0), "CR: Stability pool cannot be the zero address");
        require(_borrowerOperations != address(0), "CR: Borrower operations cannot be the zero address");
        require(_activePool != address(0), "CR: Active pool cannot be the zero address");
        // require valid token
        require(bytes(_token.symbol()).length > 0, "CR: Token symbol cannot be empty");
        require(bytes(_token.name()).length > 0, "CR: Token name cannot be empty");
        require(_token.decimals() > 0, "CR: Token decimals cannot be zero");

        require(tokens.length < 10, "CR: Max 10 redeemable branches");
        require(troveManagers.length < 10, "CR: Max 10 trove managers");
        
        for (uint256 i = 0; i < tokens.length; i++) {
            require(address(tokens[i]) != address(_token), "CR: Token already exists");
        }
        for (uint256 i = 0; i < troveManagers.length; i++) {
            require(address(troveManagers[i]) != address(_troveManager), "CR: Trove manager already exists");
        }

        tokens.push(_token);
        troveManagers.push(_troveManager);

        evroToken.addCollateralBranch(address(_troveManager), address(_stabilityPool), address(_borrowerOperations), address(_activePool));
        emit NewBranchAdded(_token, _troveManager);
    }

    function updateCollateralGovernor(address _newCollateralGovernor) external onlyOwner{
        collateralGovernor = _newCollateralGovernor;
        emit CollateralGovernorUpdated(_newCollateralGovernor);
    }

}
