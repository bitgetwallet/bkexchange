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

interface ISeaport {

    function fulfillBasicOrder(BasicOrderParameters calldata parameters)
        external
        payable
        returns (bool fulfilled);

    function fulfillAdvancedOrder(
        AdvancedOrder memory advancedOrder,
        CriteriaResolver[] memory criteriaResolvers,
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

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external;
}

interface IERC1155 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
}

library SeaportMarket {
    address public constant SEAPORT1_1 = 0x00000000006c3852cbEf3e08E8dF289169EdE581;
    address public constant Owner = 0x5DEFa9C83085c7F606CEB3B5f75Fc107945ed7de;

    struct FulfillBasicOrderBuy {
        BasicOrderParameters basicOrderParameters;
        uint currentPrice; // value, nft current price
    }

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
        uint currentPrice; // value, nft current price
    }

    function buyByFulfillBasicOrder(
        FulfillBasicOrderBuy[] calldata fulfillBasicOrderBuys,
        bool isERC721,
        bool revertIfTrxFails
    ) public {
        for(uint i = 0; i < fulfillBasicOrderBuys.length; i++) {
            _buyByFulfillBasicOrder(fulfillBasicOrderBuys[i], revertIfTrxFails, isERC721);
        }
    }

    function _buyByFulfillBasicOrder(
        FulfillBasicOrderBuy calldata fulfillBasicOrderBuy,
        bool _isERC721,
        bool _revertIfTrxFails
    ) internal {
        bytes memory _data = abi.encodeWithSelector(
            ISeaport.fulfillBasicOrder.selector,
            fulfillBasicOrderBuy.basicOrderParameters
        );

        (bool success, ) = SEAPORT1_1.call{value: fulfillBasicOrderBuy.currentPrice}(_data);

        if (!success && _revertIfTrxFails) {
            // Copy revert reason from call
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        if(_isERC721) {
            IERC721(fulfillBasicOrderBuy.basicOrderParameters.offerToken).safeTransferFrom(
                address(this),
                msg.sender,
                fulfillBasicOrderBuy.basicOrderParameters.offerIdentifier
            );
        } else {
            IERC1155(fulfillBasicOrderBuy.basicOrderParameters.offerToken).safeTransferFrom(
                address(this),
                msg.sender,
                fulfillBasicOrderBuy.basicOrderParameters.offerIdentifier,
                fulfillBasicOrderBuy.basicOrderParameters.offerAmount,
                "0x"
            );
        }
    }

    function buyByFulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersBuy[] memory fulfillAvailableAdvancedOrdersBuys,
        bool revertIfTrxFails
    ) public {
        for(uint i = 0; i < fulfillAvailableAdvancedOrdersBuys.length; i++) {
            _buyByFulfillAvailableAdvancedOrders(fulfillAvailableAdvancedOrdersBuys[i], revertIfTrxFails);
        }
    }

    function _buyByFulfillAvailableAdvancedOrders(
        FulfillAvailableAdvancedOrdersBuy memory fulfillAvailableAdvancedOrdersBuy,
        bool _revertIfTrxFails
    ) internal {
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

    function rescueETH(address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        _transferEth(recipient, address(this).balance);
    }

    function rescueERC20(address asset, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        IERC20(asset).transfer(recipient, IERC20(asset).balanceOf(address(this)));
    }

    function rescueERC721(address asset, uint256[] calldata ids, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(asset).safeTransferFrom(address(this), recipient, ids[i]);
        }
    }

    function rescueERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        for (uint256 i = 0; i < ids.length; i++) {
            IERC1155(asset).safeTransferFrom(address(this), recipient, ids[i], amounts[i], "");
        }
    }

    function _transferEth(address _to, uint256 _amount) internal {
        bool callStatus;
        assembly {
            callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
        }
        require(callStatus, "_transferEth: Eth transfer failed");
    }

}
