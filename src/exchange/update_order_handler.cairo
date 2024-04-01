//! Contract to handle creation, execution and cancellation of orders.

// *************************************************************************
//                                  IMPORTS
// *************************************************************************

// Core lib imports.
use starknet::ContractAddress;
use satoru::order::{base_order_utils::CreateOrderParams, order::Order};
use satoru::exchange::{
        base_order_handler::{IBaseOrderHandler, BaseOrderHandler}
    };

// *************************************************************************
//                  Interface of the `UpdateOrderHandler` contract.
// *************************************************************************
#[starknet::interface]
trait IUpdateOrderHandler<TContractState> {
    /// Updates the given order with the specified size delta, acceptable price, and trigger price.
    /// The `updateOrder()` feature must be enabled for the given order type. The caller must be the owner
    /// of the order, and the order must not be a market order. The size delta, trigger price, and
    /// acceptable price are updated on the order, and the order is unfrozen. Any additional FEE_TOKEN that is
    /// transferred to the contract is added to the order's execution fee. The updated order is then saved
    /// in the order store, and an `OrderUpdated` event is emitted.
    ///
    /// A user may be able to observe exchange prices and prevent order execution by updating the order's
    /// trigger price or acceptable price
    ///
    /// The main front-running concern is if a user knows whether the price is going to move up or down
    /// then positions accordingly, e.g. if price is going to move up then the user opens a long position
    ///
    /// With updating of orders, a user may know that price could be lower and delays the execution of an
    /// order by updating it, this should not be a significant front-running concern since it is similar
    /// to observing prices then creating a market order as price is decreasing
    /// # Arguments
    /// * `key` - The unique ID of the order to be updated.
    /// * `size_delta_usd` - The new size delta for the order.
    /// * `acceptable_price` - The new acceptable price for the order.
    /// * `trigger_price` - The new trigger price for the order.
    /// * `min_output_amount` - The minimum output amount for decrease orders and swaps.
    /// * `order` - The order to update that will be stored.
    /// # Returns
    /// The updated order.
    fn update_order(
        ref self: TContractState,
        key: felt252,
        size_delta_usd: u256,
        acceptable_price: u256,
        trigger_price: u256,
        min_output_amount: u256,
        order: Order
    ) -> Order;
}

#[starknet::contract]
mod UpdateOrderHandler {
    // *************************************************************************
    //                               IMPORTS
    // *************************************************************************

    // Core lib imports.
    use core::starknet::SyscallResultTrait;
    use core::traits::Into;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_contract_address};
    use array::ArrayTrait;
    use debug::PrintTrait;

    // Local imports.
    use satoru::order::{
        base_order_utils::CreateOrderParams, order_utils, order, base_order_utils,
        order::{Order, OrderTrait, OrderType, SecondaryOrderType},
        order_vault::{IOrderVaultDispatcher, IOrderVaultDispatcherTrait}
    };
    use satoru::market::error::MarketError;
    use satoru::position::error::PositionError;
    use satoru::feature::error::FeatureError;
    use satoru::order::error::OrderError;
    use satoru::exchange::exchange_utils;
    use satoru::exchange::base_order_handler::{IBaseOrderHandler, BaseOrderHandler};
    use satoru::exchange::base_order_handler::BaseOrderHandler::{
        role_store::InternalContractMemberStateTrait as RoleStoreStateTrait,
        data_store::InternalContractMemberStateTrait as DataStoreStateTrait,
        event_emitter::InternalContractMemberStateTrait as EventEmitterStateTrait,
        order_vault::InternalContractMemberStateTrait as OrderVaultStateTrait,
        referral_storage::InternalContractMemberStateTrait as ReferralStorageStateTrait,
        oracle::InternalContractMemberStateTrait as OracleStateTrait,
        InternalTrait as BaseOrderHandleInternalTrait,
    };
    use satoru::feature::feature_utils;
    use satoru::data::data_store::{IDataStoreDispatcher, IDataStoreDispatcherTrait};
    use satoru::event::event_emitter::{IEventEmitterDispatcher, IEventEmitterDispatcherTrait};
    use satoru::data::keys;
    use satoru::role::role;
    use satoru::role::role_module::{RoleModule, IRoleModule};
    use satoru::role::role_store::{IRoleStoreDispatcher, IRoleStoreDispatcherTrait};
    use satoru::token::token_utils;
    use satoru::gas::gas_utils;
    use satoru::utils::global_reentrancy_guard;
    use satoru::utils::error_utils;
    use satoru::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::contract_address_const;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {}

    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************

    /// Constructor of the contract.
    /// # Arguments
    /// * `data_store_address` - The address of the `DataStore` contract.
    /// * `role_store_address` - The address of the `RoleStore` contract.
    /// * `event_emitter_address` - The address of the EventEmitter contract.
    /// * `order_vault_address` - The address of the `OrderVault` contract.
    /// * `oracle_address` - The address of the `Oracle` contract.
    /// * `swap_handler_address` - The address of the `SwapHandler` contract.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        data_store_address: ContractAddress,
        role_store_address: ContractAddress,
        event_emitter_address: ContractAddress,
        order_vault_address: ContractAddress,
        oracle_address: ContractAddress,
        swap_handler_address: ContractAddress,
        referral_storage_address: ContractAddress
    ) {
        let mut state: BaseOrderHandler::ContractState =
            BaseOrderHandler::unsafe_new_contract_state();
        IBaseOrderHandler::initialize(
            ref state,
            data_store_address,
            role_store_address,
            event_emitter_address,
            order_vault_address,
            oracle_address,
            swap_handler_address,
            referral_storage_address
        );
    }


    // *************************************************************************
    //                          EXTERNAL FUNCTIONS
    // *************************************************************************
    #[abi(embed_v0)]
    impl UpdateOrderHandlerImpl of super::IUpdateOrderHandler<ContractState> {
        fn update_order(
            ref self: ContractState,
            key: felt252,
            size_delta_usd: u256,
            acceptable_price: u256,
            trigger_price: u256,
            min_output_amount: u256,
            order: Order
        ) -> Order {
            // Check only controller.
            let role_module_state = RoleModule::unsafe_new_contract_state();
            role_module_state.only_controller();

            // Fetch data store.
            let base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let data_store = base_order_handler_state.data_store.read();
            let event_emitter = base_order_handler_state.event_emitter.read();

            global_reentrancy_guard::non_reentrant_before(data_store);

            // Validate feature.
            feature_utils::validate_feature(
                data_store,
                keys::update_order_feature_disabled_key(get_contract_address(), order.order_type)
            );

            assert(base_order_utils::is_market_order(order.order_type), 'OrderNotUpdatable');

            let mut updated_order = order.clone();
            updated_order.size_delta_usd = size_delta_usd;
            updated_order.trigger_price = trigger_price;
            updated_order.acceptable_price = acceptable_price;
            updated_order.min_output_amount = min_output_amount;
            updated_order.is_frozen = false;

            // Allow topping up of execution fee as frozen orders will have execution fee reduced.
            let fee_token = token_utils::fee_token(data_store);
            let order_vault = base_order_handler_state.order_vault.read();
            let received_fee_token = order_vault.record_transfer_in(fee_token);
            updated_order.execution_fee = received_fee_token;

            let estimated_gas_limit = gas_utils::estimate_execute_order_gas_limit(
                data_store, @updated_order
            );
            gas_utils::validate_execution_fee(
                data_store, estimated_gas_limit, updated_order.execution_fee
            );

            updated_order.touch();

            base_order_utils::validate_non_empty_order(@updated_order);

            data_store.set_order(key, updated_order);
            event_emitter
                .emit_order_updated(
                    key, size_delta_usd, acceptable_price, trigger_price, min_output_amount
                );

            global_reentrancy_guard::non_reentrant_after(data_store);

            updated_order
        }
    }

    // ***********************************************a**************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl of InternalTrait {}
}
