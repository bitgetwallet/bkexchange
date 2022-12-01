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

    // 设置bkswap合约地址
    function setBKSwapAddress(address _bkswap) external onlyOwner {
        bkswap = _bkswap;
        emit SetBKSwapAddress(msg.sender, _bkswap);
    }

    // 设置市场注册器
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

    /// @dev batch buy with eth
    /// @param _tradeDetails trade details array
    /// @param _userAddr user address dust tokens will return to
    /// @param _requireAllSuccess require all trade to be success
    function batchBuyWithETH(
        TradeDetails[] calldata _tradeDetails,
        address _userAddr,
        bool _requireAllSuccess
    ) payable external handleDustETH(_userAddr) whenNotPaused nonReentrant {
        // trade
        _trade(_tradeDetails, _userAddr, _requireAllSuccess);
    }

    /// @dev batch buy with tokens
    /// @param _tradeDetails trade details array
    /// @param _swapDetails details array for swap by bkswap
    /// @param _allTokens erc20 tokens, including in and out
    /// @param _userAddr user address that dust tokens will be returned to
    /// @param _requireAllSuccess require all trades to be successful
    function batchBuyWithERC20s(
        TradeDetails[] calldata _tradeDetails,
        SwapDetails[] calldata _swapDetails,
        address[] calldata _allTokens,
        address _userAddr,
        bool _requireAllSuccess
    ) payable external handleDustERC20s(_allTokens, _userAddr) whenNotPaused nonReentrant {
        // approve to max for all tokens
        _approveToSwap(_allTokens);

        // swap to desired asset
        _swapToDesired(_swapDetails);

        // trade NFT
        _trade(_tradeDetails, _userAddr, _requireAllSuccess);
    }

    function _trade(
        TradeDetails[] memory _tradeDetails,
        address _userAddr,
        bool _requireAllSuccess
    ) internal {
        for (uint256 i = 0; i < _tradeDetails.length; i++) {
            // get market details
            (address _proxy, bool _isLib, bool _isActive) = marketRegistry.markets(_tradeDetails[i].marketId);
            // market should be active
            require(_isActive, "_trade: InActive Market");
            // execute trade (opensea ethereum contract)
            // opensea v1 & v2 (ETH)

            (bool success, bytes data) = _isLib
                ? _proxy.delegatecall(_tradeDetails[i].tradeData)
                : _proxy.call{value:_tradeDetails[i].value}(_tradeDetails[i].tradeData);
            // check if the call passed successfully
            if(_requireAllSuccess) _checkCallResult(success);
            if(!success){
                emit TradeError(_userAddr, i, _tradeDetails[i], data);
            }
        }
    }

    /// @dev approve to swap for max amount
    function _approveToSwap(
        address[] calldata _allTokens
    ) internal {
        for (uint256 i = 0; i < _allTokens.length; i++) {
            TransferHelper.approveMax(_allTokens[i], bkswap, type(uint256).max);
        }
    }

    /// @dev multi swap to desired asset
    function _swapToDesired(
        SwapDetails[] memory _swapDetails
    ) internal {
        for (uint256 i = 0; i < _swapDetails.length; i++) {
            // swap to desired asset
            (bool success, ) = bkswap.call{value: _swapDetails[i].value}(_swapDetails[i].swapData);
            // check if the call passed successfully
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
