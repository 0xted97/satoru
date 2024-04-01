//! Contract to handle creation, execution and cancellation of orders.

// *************************************************************************
//                                  IMPORTS
// *************************************************************************

// Core lib imports.
use starknet::ContractAddress;
// Local imports.
use satoru::oracle::oracle_utils::{SetPricesParams, SimulatePricesParams};
use satoru::order::{base_order_utils::CreateOrderParams, order::Order};

// *************************************************************************
//                  Interface of the `OrderHandler` contract.
// *************************************************************************
#[starknet::interface]
trait ICreateOrderHandler<TContractState> {
    /// Creates an order in the order store.
    /// # Arguments
    /// * `account` - The order's account.
    /// * `params` - The parameters used to create the order.
    /// # Returns
    /// The key of where the order is stored.
    fn create_order(
        ref self: TContractState, account: ContractAddress, params: CreateOrderParams
    ) -> felt252;

}

#[starknet::contract]
mod CreateOrderHandler {
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
    use super::ICreateOrderHandler;
    use satoru::oracle::{
        oracle_modules, oracle_utils, oracle_utils::{SetPricesParams, SimulatePricesParams}
    };
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
    impl OrderHandlerImpl of super::ICreateOrderHandler<ContractState> {
        fn create_order(
            ref self: ContractState, account: ContractAddress, params: CreateOrderParams
        ) -> felt252 {
            // Check only controller.
            let role_module_state = RoleModule::unsafe_new_contract_state();
            role_module_state.only_controller();
            // Fetch data store.
            let base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let data_store = base_order_handler_state.data_store.read();

            global_reentrancy_guard::non_reentrant_before(data_store);

            // Validate feature and create order.
            feature_utils::validate_feature(
                data_store,
                keys::create_order_feature_disabled_key(get_contract_address(), params.order_type)
            );
            let key = order_utils::create_order(
                data_store,
                base_order_handler_state.event_emitter.read(),
                base_order_handler_state.order_vault.read(),
                base_order_handler_state.referral_storage.read(),
                account,
                params
            );

            global_reentrancy_guard::non_reentrant_after(data_store);

            key
        }
    }

    // ***********************************************a**************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl of InternalTrait {}
}
