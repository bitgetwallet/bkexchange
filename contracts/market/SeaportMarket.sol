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

// {
// 	"24160d74": "buyByFulfillAdvancedOrder(SeaportMarket.FulfillAdvancedOrderBuy[],bool)",
// 	"91392c2c": "buyByFulfillAvailableAdvancedOrders(SeaportMarket.FulfillAvailableAdvancedOrdersBuy[],bool)",
// 	"026a04cf": "buyByFulfillBasicOrder(SeaportMarket.FulfillBasicOrderBuy[],bool,bool)",
// }
/// 调用lib中public方法要用上面的签名
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

/// @dev library的方法签名和contract的方法签名不同，调用library的public方法的时候需要将方法签名替换成contract的方法签名，否则会调用不成功
///      hardhat有个bug，在本地环境调试会失败，但是部署到测试网会成功，也是因为上述原因，hardhat没有得到正确的方法签名
///      参考 https://ethereum.stackexchange.com/questions/129201/how-do-i-pass-a-struct-as-an-argument-in-delegatecall-to-a-proxy-library
///      例如，在library中，buyAssetsForETH(SeaportMarket.SeaportBuy[],bool) = 0x405b5cc4
library SeaportMarket {
    address public constant SEAPORT1_1 = 0x00000000006c3852cbEf3e08E8dF289169EdE581; // 主网
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

    /// @dev 基本订单购买，无法指定NFT接收者，所以购买成功后需要将NFT转给买家
    /// function signature = 0x026a04cf
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

        // 修改为msg.value 不用担心卡币，periphery合约中有退款逻辑
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

    /// @dev 高级订单应该以这个接口为主，填充可用的高级订单，防止在执行中部分订单已被其他人买走
    /// 填充可用高级订单，可将基础订单填充在这里，recipient是交易结果的接收者 0x91392c2c
    /// @param fulfillAvailableAdvancedOrdersBuys 可用高级订单参数数组，用于批量购买
    /// @param revertIfTrxFails 如果tx失败是否revert整个交易，如果可忽略失败订单，传false表示忽略失败订单
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

    /// @dev 不建议作为填充高级订单的主要接口使用，并发的情况下可能会失败
    /// 填充高级订单，支持批量购买 0x24160d74，目前使用的是这个接口
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

    // Emergency function: In case any ETH get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueETH(address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        _transferEth(recipient, address(this).balance);
    }

    // Emergency function: In case any ERC20 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC20(address asset, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        IERC20(asset).transfer(recipient, IERC20(asset).balanceOf(address(this)));
    }

    // Emergency function: In case any ERC721 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC721(address asset, uint256[] calldata ids, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(asset).safeTransferFrom(address(this), recipient, ids[i]);
        }
    }

    // Emergency function: In case any ERC1155 tokens get stuck in the contract unintentionally
    // Only owner can retrieve the asset balance to a recipient address
    function rescueERC1155(address asset, uint256[] calldata ids, uint256[] calldata amounts, address recipient) external {
        require(msg.sender == Owner, "caller not owner");
        for (uint256 i = 0; i < ids.length; i++) {
            IERC1155(asset).safeTransferFrom(address(this), recipient, ids[i], amounts[i], "");
        }
    }

    function _transferEth(address _to, uint256 _amount) internal {
        bool callStatus;
        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
        }
        require(callStatus, "_transferEth: Eth transfer failed");
    }

}
