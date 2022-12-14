// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

// prettier-ignore
import {
    OrderComponents,
    Fulfillment,
    FulfillmentComponent,
    Execution,
    Order,
    AdvancedOrder,
    OrderStatus,
    CriteriaResolver
} from "../lib/ConsiderationStructs.sol";

interface ISeaport {
    function fulfillAdvancedOrder(
        AdvancedOrder calldata advancedOrder,
        CriteriaResolver[] calldata criteriaResolvers,
        bytes32 fulfillerConduitKey,
        address recipient
    ) external payable returns (bool fulfilled);

    function fulfillAvailableAdvancedOrders(
        AdvancedOrder[] calldata advancedOrders,
        CriteriaResolver[] calldata criteriaResolvers,
        FulfillmentComponent[][] calldata offerFulfillments,
        FulfillmentComponent[][] calldata considerationFulfillments,
        bytes32 fulfillerConduitKey,
        address recipient, // 购买的所有物品的指定接收人
        uint256 maximumFulfilled
    )
        external
        payable
        returns (bool[] memory availableOrders, Execution[] memory executions);

}

library SeaportMarket {
    address public constant SEAPORT1_1 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;

    struct FulfillAdvancedOrderBuy {
        AdvancedOrder advancedOrder;
        CriteriaResolver[] criteriaResolvers;
        bytes32 fulfillerConduitKey;
        address recipient;
        uint currentPrice; // value, nft current price
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

    function buyByFulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersBuy[] calldata fulfillAvailableAdvancedOrdersBuys,
        bool revertIfTrxFails
    ) public {
        for(uint i = 0; i < fulfillAvailableAdvancedOrdersBuys.length; i++) {
            _buyByFulfillAvailableAdvancedOrders(fulfillAvailableAdvancedOrdersBuys[i], revertIfTrxFails);
        }
    }

    function _buyByFulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersBuy calldata fulfillAvailableAdvancedOrdersBuy,
        bool _revertIfTrxFails
    ) internal {
        require(fulfillAvailableAdvancedOrdersBuy.recipient != address(0), "recipient cannot be zero address");
        bytes memory _data = abi.encodeWithSelector(
            ISeaport.fulfillAvailableAdvancedOrders.selector,
            fulfillAvailableAdvancedOrdersBuy.advancedOrders,
            fulfillAvailableAdvancedOrdersBuy.criteriaResolvers,
            fulfillAvailableAdvancedOrdersBuy.offerFulfillments,
            fulfillAvailableAdvancedOrdersBuy.considerationFulfillments,
            fulfillAvailableAdvancedOrdersBuy.fulfillerConduitKey,
            fulfillAvailableAdvancedOrdersBuy.recipient,
            fulfillAvailableAdvancedOrdersBuy.maximumFulfilled
        );

        (bool success, ) = SEAPORT1_1.call{value: fulfillAvailableAdvancedOrdersBuy.currentPrice}(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }

    function buyByFulfillAdvancedOrder(
        FulfillAdvancedOrderBuy[] calldata fulfillAdvancedOrderBuys,
        bool revertIfTrxFails
    ) public {
        for(uint i = 0; i < fulfillAdvancedOrderBuys.length; i++) {
            _buyByFulfillAdvancedOrder(fulfillAdvancedOrderBuys[i], revertIfTrxFails);
        }
    }

    function _buyByFulfillAdvancedOrder(
        FulfillAdvancedOrderBuy calldata fulfillAdvancedOrderBuy,
        bool _revertIfTrxFails
    ) internal {
        require(fulfillAdvancedOrderBuy.recipient != address(0), "recipient cannot be zero address");
        bytes memory _data = abi.encodeWithSelector(
            ISeaport.fulfillAdvancedOrder.selector,
            fulfillAdvancedOrderBuy.advancedOrder,
            fulfillAdvancedOrderBuy.criteriaResolvers,
            fulfillAdvancedOrderBuy.fulfillerConduitKey,
            fulfillAdvancedOrderBuy.recipient
        );

        (bool success, ) = SEAPORT1_1.call{value: fulfillAdvancedOrderBuy.currentPrice}(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
    }
}
