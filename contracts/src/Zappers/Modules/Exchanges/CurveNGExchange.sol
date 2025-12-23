// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../Interfaces/IEvroToken.sol";
import "./Curve/ICurveStableswapNGPool.sol";
import "../../Interfaces/IExchange.sol";

contract CurveNGExchange is IExchange {
    using SafeERC20 for IERC20;

    IERC20 public immutable collToken;
    IEvroToken public immutable evroToken;
    ICurveStableswapNGPool public immutable curvePool;
    int128 public immutable COLL_TOKEN_INDEX;
    int128 public immutable BOLD_TOKEN_INDEX;

    constructor(
        IERC20 _collToken,
        IEvroToken _evroToken,
        ICurveStableswapNGPool _curvePool,
        int128 _collIndex,
        int128 _evroIndex
    ) {
        collToken = _collToken;
        evroToken = _evroToken;
        curvePool = _curvePool;
        COLL_TOKEN_INDEX = _collIndex;
        BOLD_TOKEN_INDEX = _evroIndex;
    }

    function swapFromEvro(uint256 _evroAmount, uint256 _minCollAmount) external {
        ICurveStableswapNGPool curvePoolCached = curvePool;
        uint256 initialEvroBalance = evroToken.balanceOf(address(this));
        evroToken.transferFrom(msg.sender, address(this), _evroAmount);
        evroToken.approve(address(curvePoolCached), _evroAmount);

        uint256 output = curvePoolCached.exchange(BOLD_TOKEN_INDEX, COLL_TOKEN_INDEX, _evroAmount, _minCollAmount);
        collToken.safeTransfer(msg.sender, output);

        uint256 currentEvroBalance = evroToken.balanceOf(address(this));
        if (currentEvroBalance > initialEvroBalance) {
            evroToken.transfer(msg.sender, currentEvroBalance - initialEvroBalance);
        }
    }

    function swapToEvro(uint256 _collAmount, uint256 _minEvroAmount) external returns (uint256) {
        ICurveStableswapNGPool curvePoolCached = curvePool;
        uint256 initialCollBalance = collToken.balanceOf(address(this));
        collToken.safeTransferFrom(msg.sender, address(this), _collAmount);
        collToken.approve(address(curvePoolCached), _collAmount);

        uint256 output = curvePoolCached.exchange(COLL_TOKEN_INDEX, BOLD_TOKEN_INDEX, _collAmount, _minEvroAmount);
        evroToken.transfer(msg.sender, output);

        uint256 currentCollBalance = collToken.balanceOf(address(this));
        if (currentCollBalance > initialCollBalance) {
            collToken.safeTransfer(msg.sender, currentCollBalance - initialCollBalance);
        }

        return output;
    }
}
