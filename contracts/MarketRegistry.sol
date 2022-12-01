// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";

///@dev 交易市场管理器
contract MarketRegistry is Ownable {
    event SetMarketProxy(
        uint indexed index,
        Market market
    );
    struct Market {
        address proxy;
        bool isLib;
        bool isActive;
    }

    Market[] public markets;

    constructor(address[] memory proxies, bool[] memory isLibs, address _owner) {
        for (uint256 i = 0; i < proxies.length; i++) {
            markets.push(Market(proxies[i], isLibs[i], true));
            emit SetMarketProxy(i, Market(proxies[i], isLibs[i], true));
        }
        _transferOwnership(_owner);
    }

    function addMarket(address proxy, bool isLib) external onlyOwner {
        markets.push(Market(proxy, isLib, true));
        emit SetMarketProxy(markets.length - 1, Market(proxy, isLib, true));
    }

    function setMarketStatus(uint256 marketId, bool newStatus) external onlyOwner {
        Market storage market = markets[marketId];
        market.isActive = newStatus;
        emit SetMarketProxy(marketId, markets[marketId]);
    }

    function setMarketProxy(uint256 marketId, address newProxy, bool isLib) external onlyOwner {
        Market storage market = markets[marketId];
        market.proxy = newProxy;
        market.isLib = isLib;
        emit SetMarketProxy(marketId, markets[marketId]);
    }
}
