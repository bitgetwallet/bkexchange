// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

// prettier-ignore
import {
    BasicOrderParameters,
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

interface ISeaportMarket {
    struct FulfillAdvancedOrderBuy {
        AdvancedOrder advancedOrder;
        CriteriaResolver[] criteriaResolvers;
        bytes32 fulfillerConduitKey;
        address recipient;
        uint currentPrice;
    }

    struct FulfillAvailableAdvancedOrdersBuy {
        AdvancedOrder[] advancedOrders;
        CriteriaResolver[] criteriaResolvers;
        FulfillmentComponent[][] offerFulfillments;
        FulfillmentComponent[][] considerationFulfillments;
        bytes32 fulfillerConduitKey;
        address recipient;
        uint256 maximumFulfilled;
        uint currentPrice;
    }

    function buyByFulfillAdvancedOrder(
        FulfillAdvancedOrderBuy[] calldata fulfillAdvancedOrderBuys,
        bool revertIfTrxFails
    ) external;

    function buyByFulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersBuy[] calldata fulfillAvailableAdvancedOrdersBuys,
        bool revertIfTrxFails
    ) external;

}
