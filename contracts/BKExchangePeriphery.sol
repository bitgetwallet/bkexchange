// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "./MarketRegistry.sol";
import "./utils/TransferHelper.sol";
import "./BKCommon.sol";

contract BKExchangePeriphery is BKCommon {
    address public bkswap;
    bool public openForTrades;
    MarketRegistry public marketRegistry;

    event SetMarketRegistry(address operator, address bkRegistry);
    event SetBKSwapAddress(address operator, address bkRegistry);
    event TradeError(
        address indexed userAddr,
        uint index,
        TradeDetails tradeDetail,
        bytes errorData
    );

    struct OpenseaTrades {
        uint256 value;
        bytes tradeData;
    }

    struct TradeDetails {
        uint256 marketId;
        uint256 value;
        bytes tradeData;
    }

    struct SwapDetails {
        uint256 value;
        bytes swapData;
    }


    constructor(address _marketRegistry, address _bkswap, address _owner) {
        bkswap = _bkswap;
        emit SetBKSwapAddress(msg.sender, _bkswap);

        marketRegistry = MarketRegistry(_marketRegistry);
        emit SetMarketRegistry(msg.sender, _marketRegistry);
        _transferOwnership(_owner);
    }

    function setBKSwapAddress(address _bkswap) external onlyOwner {
        bkswap = _bkswap;
        emit SetBKSwapAddress(msg.sender, _bkswap);
    }

    function setMarketRegistry(address _marketRegistry) external onlyOwner {
        marketRegistry = MarketRegistry(_marketRegistry);
        emit SetMarketRegistry(msg.sender, _marketRegistry);
    }

    modifier handleDustETH(address _userAddr) {
        _;

        uint256 newBalance = address(this).balance;
        if(newBalance > 0){
            TransferHelper.safeTransferETH(_userAddr, newBalance);
        }
    }

    modifier handleDustERC20s(address[] calldata _allTokens, address _userAddr) {
        _;

        uint256 newBalance = address(this).balance;
        if (newBalance > 0) {
            TransferHelper.safeTransferETH(_userAddr, newBalance);
        }

        for (uint256 i = 0; i < _allTokens.length; i++) {
            uint256 erc20NewBalance = IERC20(_allTokens[i]).balanceOf(address(this));

            if(erc20NewBalance > 0){
                TransferHelper.safeTransfer(
                    _allTokens[i],
                    _userAddr,
                    erc20NewBalance
                );
            }
        }
    }


    function batchBuyWithETH(
        TradeDetails[] calldata _tradeDetails,
        address _userAddr,
        bool _requireAllSuccess
    ) payable external handleDustETH(_userAddr) whenNotPaused nonReentrant {
        // trade
        _trade(_tradeDetails, _userAddr, _requireAllSuccess);
    }

    function batchBuyWithERC20s(
        TradeDetails[] calldata _tradeDetails,
        SwapDetails[] calldata _swapDetails,
        address[] calldata _allTokens,
        address _userAddr,
        bool _requireAllSuccess
    ) payable external handleDustERC20s(_allTokens, _userAddr) whenNotPaused nonReentrant {
        _approveToSwap(_allTokens);

        _swapToDesired(_swapDetails);

        _trade(_tradeDetails, _userAddr, _requireAllSuccess);
    }

    function _trade(
        TradeDetails[] memory _tradeDetails,
        address _userAddr,
        bool _requireAllSuccess
    ) internal {
        for (uint256 i = 0; i < _tradeDetails.length; i++) {
            (address _proxy, bool _isLib, bool _isActive) = marketRegistry.markets(_tradeDetails[i].marketId);
            require(_isActive, "_trade: InActive Market");

            (bool success, bytes memory data) = _isLib
                ? _proxy.delegatecall(_tradeDetails[i].tradeData)
                : _proxy.call{value:_tradeDetails[i].value}(_tradeDetails[i].tradeData);

            if(_requireAllSuccess) _checkCallResult(success);
            if(!success){
                emit TradeError(_userAddr, i, _tradeDetails[i], data);
            }
        }
    }

    function _approveToSwap(
        address[] calldata _allTokens
    ) internal {
        for (uint256 i = 0; i < _allTokens.length; i++) {
            TransferHelper.approveMax(IERC20(_allTokens[i]), bkswap, type(uint256).max);
        }
    }

    function _swapToDesired(
        SwapDetails[] memory _swapDetails
    ) internal {
        for (uint256 i = 0; i < _swapDetails.length; i++) {
            (bool success, ) = bkswap.call{value: _swapDetails[i].value}(_swapDetails[i].swapData);
            _checkCallResult(success);
        }
    }

    function _checkCallResult(bool _success) internal pure {
        if (!_success) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function setOneTimeApproval(IERC20 token, address operator, uint256 amount) external onlyOwner {
        token.approve(operator, amount);
    }
}
