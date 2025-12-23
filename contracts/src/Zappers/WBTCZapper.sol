// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./BaseZapper.sol";
import "../Dependencies/Constants.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IWBTCWrapper} from "../Interfaces/IWBTCWrapper.sol";
import {ITroveManager} from "../Interfaces/ITroveManager.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract WBTCZapper is BaseZapper {
    IERC20 public immutable wBTC;
    IWBTCWrapper public immutable wBTCWrapper;

    constructor(IAddressesRegistry _addressesRegistry, IFlashLoanProvider _flashLoanProvider, IExchange _exchange)
        BaseZapper(_addressesRegistry, _flashLoanProvider, _exchange)
    {
        wBTCWrapper = IWBTCWrapper(address(_addressesRegistry.collToken()));
        // will throw if collToken is not a ERC20Wrapper
        wBTC = IERC20(wBTCWrapper.underlying());
        require(address(wBTC) != address(0), "WBTCZapper: WBTC address is zero");
        require(address(borrowerOperations) != address(0), "WBTCZapper: borrowerOperations is zero");
        require(address(_exchange) != address(0), "WBTCZapper: exchange is zero");
       
        // Approve coll to BorrowerOperations
        wBTCWrapper.approve(address(borrowerOperations), type(uint256).max);
        // Approve Coll to exchange module (for closeTroveFromCollateral)
        wBTCWrapper.approve(address(_exchange), type(uint256).max);
        // Approve WETH to BorrowerOperations for gas compensation
        WETH.approve(address(borrowerOperations), type(uint256).max);
    }
    function openTroveWithRawETH(OpenTroveParams calldata /*_params*/) external payable returns (uint256) {
        revert("WBTCZapper: Not implemented");
    }

    // @audit-info name is an artifact of the IZapper interface should be openTroveWithRawWBTC but we have to call it this to use the BaseZapper
    function openTroveWithWBTC(OpenTroveParams calldata _params) external payable returns (uint256) {
        require(_params.collAmount > 0, "WBTCZapper: Insufficient WBTC");
        require(msg.value == ETH_GAS_COMPENSATION, "WBTCZapper: Wrong ETH amount");
        require(
            _params.batchManager == address(0) || _params.annualInterestRate == 0,
            "WBTCZapper: Cannot choose interest if joining a batch"
        );
        uint256 wbtcAmount = _params.collAmount / 1e10;
        require(wbtcAmount > 0, "WBTCZapper: Amount too small");
        
        // Convert ETH to WETH for gas compensation
        WETH.deposit{value: msg.value}();
        
        // Pull WBTC from user (8 decimals)
        SafeTransferLib.safeTransferFrom(address(wBTC), msg.sender, address(this), wbtcAmount);
        
        // Approve wrapper to spend WBTC (8 decimals)
        wBTC.approve(address(wBTCWrapper), wbtcAmount);
        
        // Deposit WBTC (8 decimals) and receive wrapped tokens (18 decimals)
        wBTCWrapper.depositFor(address(this), wbtcAmount);

        uint256 troveId;
        // Include sender in index
        uint256 index = _getTroveIndex(_params.ownerIndex);
        if (_params.batchManager == address(0)) {
            troveId = borrowerOperations.openTrove(
                _params.owner,
                index,
                _params.collAmount,
                _params.evroAmount,
                _params.upperHint,
                _params.lowerHint,
                _params.annualInterestRate,
                _params.maxUpfrontFee,
                // Add this contract as add/receive manager to be able to fully adjust trove,
                // while keeping the same management functionality
                address(this), // add manager
                address(this), // remove manager
                address(this) // receiver for remove manager
            );
        } else {
            IBorrowerOperations.OpenTroveAndJoinInterestBatchManagerParams memory
                openTroveAndJoinInterestBatchManagerParams = IBorrowerOperations
                    .OpenTroveAndJoinInterestBatchManagerParams({
                    owner: _params.owner,
                    ownerIndex: index,
                    collAmount: _params.collAmount,
                    evroAmount: _params.evroAmount,
                    upperHint: _params.upperHint,
                    lowerHint: _params.lowerHint,
                    interestBatchManager: _params.batchManager,
                    maxUpfrontFee: _params.maxUpfrontFee,
                    // Add this contract as add/receive manager to be able to fully adjust trove,
                    // while keeping the same management functionality
                    addManager: address(this), // add manager
                    removeManager: address(this), // remove manager
                    receiver: address(this) // receiver for remove manager
                });
            troveId =
                borrowerOperations.openTroveAndJoinInterestBatchManager(openTroveAndJoinInterestBatchManagerParams);
        }

        evroToken.transfer(msg.sender, _params.evroAmount);

        // Set add/remove managers
        _setAddManager(troveId, _params.addManager);
        _setRemoveManagerAndReceiver(troveId, _params.removeManager, _params.receiver);

        return troveId;
    }

    // @audit-info name is an artifact of the IZapper interface should be addCollWithRawWBTC but we have to call it this to use the BaseZapper
    function addCollWithRawETH(uint256 /* _troveId */, uint256 /* _amount */) external payable {
        revert("WBTCZapper: Not implemented");
    }

    function addCollWithWBTC(uint256 _troveId, uint256 _amount) external {
        address owner = troveNFT.ownerOf(_troveId);
        _requireSenderIsOwnerOrAddManager(_troveId, owner);

        // _amount is in 18 decimals (wrapped token units)
        uint256 wbtcAmount = _amount / 1e10;
        require(wbtcAmount > 0, "WBTCZapper: Amount too small");
        
        // Pull WBTC from user (8 decimals)
        SafeTransferLib.safeTransferFrom(address(wBTC), msg.sender, address(this), wbtcAmount);
        
        // Approve wrapper to spend WBTC (8 decimals)
        wBTC.approve(address(wBTCWrapper), wbtcAmount);
        
        // Deposit WBTC (8 decimals) and receive wrapped tokens (18 decimals)
        wBTCWrapper.depositFor(address(this), wbtcAmount);

        // _amount is in 18 decimals (wrapped token units)
        borrowerOperations.addColl(_troveId, _amount);
    }

    // @audit-info name is an artifact of the IZapper interface should be withdrawCollToRawWBTC but we have to call it this to use the BaseZapper
    function withdrawCollToRawETH(uint256 /* _troveId */, uint256 /* _amount */) external {
        revert("WBTCZapper: Not implemented");
    }

    function withdrawCollToWBTC(uint256 _troveId, uint256 _amount) external {
        address owner = troveNFT.ownerOf(_troveId);
        address receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner);
        _requireZapperIsReceiver(_troveId);

        borrowerOperations.withdrawColl(_troveId, _amount);

        wBTCWrapper.withdrawTo(receiver, _amount);
    }

    function withdrawEvro(uint256 _troveId, uint256 _evroAmount, uint256 _maxUpfrontFee) external {
        address owner = troveNFT.ownerOf(_troveId);
        address receiver = _requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner);
        _requireZapperIsReceiver(_troveId);

        borrowerOperations.withdrawEvro(_troveId, _evroAmount, _maxUpfrontFee);

        // Send Evro
        evroToken.transfer(receiver, _evroAmount);
    }

    function repayEvro(uint256 _troveId, uint256 _evroAmount) external {
        address owner = troveNFT.ownerOf(_troveId);
        _requireSenderIsOwnerOrAddManager(_troveId, owner);

        // Set initial balances to make sure there are not lefovers
        InitialBalances memory initialBalances;
        _setInitialTokensAndBalances(wBTCWrapper, evroToken, initialBalances);

        // Pull Evro
        evroToken.transferFrom(msg.sender, address(this), _evroAmount);

        borrowerOperations.repayEvro(_troveId, _evroAmount);

        // return leftovers to user
        _returnLeftovers(initialBalances);
    }

    function adjustTroveWithWBTC(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        uint256 _maxUpfrontFee
    ) external payable {
        InitialBalances memory initialBalances;
        address payable receiver =
            _adjustTrovePre(_troveId, _collChange, _isCollIncrease, _evroChange, _isDebtIncrease, initialBalances);
        borrowerOperations.adjustTrove(
            _troveId, _collChange, _isCollIncrease, _evroChange, _isDebtIncrease, _maxUpfrontFee
        );
        _adjustTrovePost(_collChange, _isCollIncrease, _evroChange, _isDebtIncrease, receiver, initialBalances);
    }

    function adjustZombieTroveWithWBTC(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        uint256 _upperHint,
        uint256 _lowerHint,
        uint256 _maxUpfrontFee
    ) external payable {
        InitialBalances memory initialBalances;
        address payable receiver =
            _adjustTrovePre(_troveId, _collChange, _isCollIncrease, _evroChange, _isDebtIncrease, initialBalances);
        borrowerOperations.adjustZombieTrove(
            _troveId, _collChange, _isCollIncrease, _evroChange, _isDebtIncrease, _upperHint, _lowerHint, _maxUpfrontFee
        );
        _adjustTrovePost(_collChange, _isCollIncrease, _evroChange, _isDebtIncrease, receiver, initialBalances);
    }

    function _adjustTrovePre(
        uint256 _troveId,
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        InitialBalances memory _initialBalances
    ) internal returns (address payable) {
        if (_isCollIncrease) {
            // _collChange is in 18 decimals (wrapped token units)
            uint256 wbtcAmount = _collChange / 1e10;
            require(wbtcAmount > 0, "WBTCZapper: Amount too small");
            require(wbtcAmount <= wBTC.balanceOf(msg.sender), "WBTCZapper: Wrong coll amount");
        }
    
        address payable receiver =
            payable(_checkAdjustTroveManagers(_troveId, _collChange, _isCollIncrease, _isDebtIncrease));

        // Set initial balances to make sure there are not lefovers
        _setInitialTokensAndBalances(wBTCWrapper, evroToken, _initialBalances);

        // WBTC -> wWBTC
        if (_isCollIncrease) {
            // _collChange is in 18 decimals (wrapped token units)
            uint256 wbtcAmount = _collChange / 1e10;
            // Pull WBTC from user (8 decimals)
            SafeTransferLib.safeTransferFrom(address(wBTC), msg.sender, address(this), wbtcAmount);
            // Approve wrapper to spend WBTC (8 decimals)
            wBTC.approve(address(wBTCWrapper), wbtcAmount);
            // Deposit WBTC (8 decimals) and receive wrapped tokens (18 decimals)
            wBTCWrapper.depositFor(address(this), wbtcAmount);
        }

        // Pull Evro
        if (!_isDebtIncrease) {
            evroToken.transferFrom(msg.sender, address(this), _evroChange);
        }

        return receiver;
    }

    function _adjustTrovePost(
        uint256 _collChange,
        bool _isCollIncrease,
        uint256 _evroChange,
        bool _isDebtIncrease,
        address payable _receiver,
        InitialBalances memory _initialBalances
    ) internal {
        // Send Evro
        if (_isDebtIncrease) {
            evroToken.transfer(_receiver, _evroChange);
        }

        // return BOLD leftovers to user (trying to repay more than possible)
        uint256 currentEvroBalance = evroToken.balanceOf(address(this));
        if (currentEvroBalance > _initialBalances.balances[1]) {
            evroToken.transfer(_initialBalances.receiver, currentEvroBalance - _initialBalances.balances[1]);
        }
        // There shouldn’t be Collateral leftovers, everything sent should end up in the trove
        // But ETH and WETH balance can be non-zero if someone accidentally send it to this contract

        // wWBTC -> WBTC
        if (!_isCollIncrease && _collChange > 0) {
            wBTCWrapper.withdrawTo(_receiver, _collChange);
        }
    }

    function closeTroveToWBTC(uint256 _troveId) external {
        address owner = troveNFT.ownerOf(_troveId);
        address payable receiver = payable(_requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner));
        _requireZapperIsReceiver(_troveId);

        // pull Evro for repayment
        LatestTroveData memory trove = troveManager.getLatestTroveData(_troveId);
        evroToken.transferFrom(msg.sender, address(this), trove.entireDebt);

        borrowerOperations.closeTrove(_troveId);

        // Return collateral to user
        wBTCWrapper.withdrawTo(receiver, trove.entireColl);
        
        // Return gas compensation to user
        WETH.withdraw(ETH_GAS_COMPENSATION);
        (bool success,) = receiver.call{value: ETH_GAS_COMPENSATION}("");
        require(success, "WBTCZapper: Sending ETH failed");
    }

    function closeTroveFromCollateral(uint256 _troveId, uint256 _flashLoanAmount, uint256 _minExpectedCollateral)
        external
        override
    {
        address owner = troveNFT.ownerOf(_troveId);
        address payable receiver = payable(_requireSenderIsOwnerOrRemoveManagerAndGetReceiver(_troveId, owner));
        _requireZapperIsReceiver(_troveId);

        CloseTroveParams memory params = CloseTroveParams({
            troveId: _troveId,
            flashLoanAmount: _flashLoanAmount,
            minExpectedCollateral: _minExpectedCollateral,
            receiver: receiver
        });

        // Set initial balances to make sure there are not lefovers
        InitialBalances memory initialBalances;
        initialBalances.tokens[0] = wBTC;
        initialBalances.tokens[1] = evroToken;
        _setInitialBalancesAndReceiver(initialBalances, receiver);

        // Flash loan coll
        flashLoanProvider.makeFlashLoan(
            wBTC, _flashLoanAmount, IFlashLoanProvider.Operation.CloseTrove, abi.encode(params)
        );

        // return leftovers to user
        _returnLeftovers(initialBalances);
    }

    function receiveFlashLoanOnCloseTroveFromCollateral(
        CloseTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external {
        require(msg.sender == address(flashLoanProvider), "WZ: Caller not FlashLoan provider");

        LatestTroveData memory trove = troveManager.getLatestTroveData(_params.troveId);
        uint256 collLeft = trove.entireColl - _params.flashLoanAmount;
        require(collLeft >= _params.minExpectedCollateral, "WZ: Not enough collateral received");

        // Swap Coll from flash loan to Evro, so we can repay and close trove
        // We swap the flash loan minus the flash loan fee
        exchange.swapToEvro(_effectiveFlashLoanAmount, trove.entireDebt);

        // We asked for a min of entireDebt in swapToEvro call above, so we don't check again here:
        // uint256 receivedEvroAmount = exchange.swapToEvro(_effectiveFlashLoanAmount, trove.entireDebt);
        //require(receivedEvroAmount >= trove.entireDebt, "WZ: Not enough BOLD obtained to repay");

        borrowerOperations.closeTrove(_params.troveId);

        // Convert flash loan amount from WBTC (8 decimals) to wWBTC (18 decimals)
        uint256 flashLoanAmountWrapped = _params.flashLoanAmount * 1e10;
        
        // Send coll back to return flash loan (unwrap wWBTC to WBTC)
        wBTCWrapper.withdrawTo(address(flashLoanProvider), flashLoanAmountWrapped);
        
        // Return remaining collateral to user (unwrap wWBTC to WBTC)
        wBTCWrapper.withdrawTo(_params.receiver, collLeft);
        
        // Return gas compensation to user (BorrowerOperations already sent it to this zapper as WETH)
        WETH.withdraw(ETH_GAS_COMPENSATION);
        (bool success,) = _params.receiver.call{value: ETH_GAS_COMPENSATION}("");
        require(success, "WBTCZapper: Sending ETH failed");
    }

    // Unimplemented flash loan receive functions for leverage
    function receiveFlashLoanOnOpenLeveragedTrove(
        ILeverageZapper.OpenLeveragedTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    function receiveFlashLoanOnLeverUpTrove(
        ILeverageZapper.LeverUpTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}
    function receiveFlashLoanOnLeverDownTrove(
        ILeverageZapper.LeverDownTroveParams calldata _params,
        uint256 _effectiveFlashLoanAmount
    ) external virtual override {}

    receive() external payable {}
}
