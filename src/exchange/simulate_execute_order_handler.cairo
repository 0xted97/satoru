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
//                  Interface of the `ExecuteOrderHandler` contract.
// *************************************************************************
#[starknet::interface]
trait IExecuteOrderHandler<TContractState> {
    /// Executes an order.
    /// # Arguments
    /// * `key` - The key of the order to execute.
    /// * `oracle_params` - The oracle params to set prices before execution.
    fn execute_order(ref self: TContractState, key: felt252, oracle_params: SetPricesParams);

    /// Executes an order.
    /// # Arguments
    /// * `key` - The key of the order to execute.
    /// * `oracle_params` - The oracle params to set prices before execution.
    /// * `keeper` - The keeper executing the order.
    fn execute_order_keeper(
        ref self: TContractState,
        key: felt252,
        oracle_params: SetPricesParams,
        keeper: ContractAddress
    );

    /// Simulates execution of an order to check for any error.
    /// # Arguments
    /// * `key` - The key of the order to execute.
    /// * `oracle_params` - The oracle params to simulate prices.
    fn simulate_execute_order(ref self: TContractState, key: felt252, params: SimulatePricesParams);
}

#[starknet::contract]
mod ExecuteOrderHandler {
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
    use super::IExecuteOrderHandler;
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
    impl OrderHandlerImpl of super::IExecuteOrderHandler<ContractState> {
        fn execute_order(ref self: ContractState, key: felt252, oracle_params: SetPricesParams) {
            // Check only order keeper.
            let role_module_state = RoleModule::unsafe_new_contract_state();
            role_module_state.only_order_keeper();
            // Fetch data store.
            let base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let data_store = base_order_handler_state.data_store.read();
            global_reentrancy_guard::non_reentrant_before(data_store);
            // oracle_modules::with_oracle_prices_before(
            //     base_order_handler_state.oracle.read(),
            //     data_store,
            //     base_order_handler_state.event_emitter.read(),
            //     @oracle_params
            // );
            // TODO: Did not implement starting gas and try / catch logic as not available in Cairo
            self._execute_order(key, oracle_params, get_contract_address());
            // oracle_modules::with_oracle_prices_after(base_order_handler_state.oracle.read());
            global_reentrancy_guard::non_reentrant_after(data_store);
        }

        fn execute_order_keeper(
            ref self: ContractState,
            key: felt252,
            oracle_params: SetPricesParams,
            keeper: ContractAddress
        ) {
            self._execute_order(key, oracle_params, keeper);
        }

        fn simulate_execute_order(
            ref self: ContractState, key: felt252, params: SimulatePricesParams
        ) {
            // Check only order keeper.
            let role_module_state = RoleModule::unsafe_new_contract_state();
            role_module_state.only_order_keeper();

            // Fetch data store.
            let base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let data_store = base_order_handler_state.data_store.read();

            global_reentrancy_guard::non_reentrant_before(data_store);
            oracle_modules::with_simulated_oracle_prices_before(
                base_order_handler_state.oracle.read(), params
            );

            let oracle_params: SetPricesParams = Default::default();
            self._execute_order(key, oracle_params, get_contract_address());

            oracle_modules::with_simulated_oracle_prices_after();
            global_reentrancy_guard::non_reentrant_after(data_store);
        }
    }

    // ***********************************************a**************************
    //                          INTERNAL FUNCTIONS
    // *************************************************************************
    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Executes an order.
        /// # Arguments
        /// * `key` - The key of the order to execute.
        /// * `oracle_params` - The oracle params to set prices before execution.
        /// * `keeper` - The keeper executing the order.
        fn _execute_order(
            self: @ContractState,
            key: felt252,
            oracle_params: SetPricesParams,
            keeper: ContractAddress
        ) {
            let starting_gas: u256 = 100000; // TODO: Get starting gas from Cairo.

            // Check only self.
            let role_module_state = RoleModule::unsafe_new_contract_state();
            //role_module_state.only_self();

            let mut base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let params = base_order_handler_state
                .get_execute_order_params(
                    key, oracle_params, keeper, starting_gas, SecondaryOrderType::None(()),
                );

            if params.order.is_frozen || params.order.order_type == OrderType::LimitSwap(()) {
                self._validate_state_frozen_order_keeper(keeper);
            }

            // Validate feature.
            feature_utils::validate_feature(
                params.contracts.data_store,
                keys::execute_order_feature_disabled_key(
                    get_contract_address(), params.order.order_type
                )
            );

            order_utils::execute_order(params);
        }
        
        /// Validate that the keeper is a frozen order keeper.
        /// # Arguments
        /// * `keeper` - address of the keeper.
        fn _validate_state_frozen_order_keeper(self: @ContractState, keeper: ContractAddress) {
            let mut base_order_handler_state = BaseOrderHandler::unsafe_new_contract_state();
            let role_store = base_order_handler_state.role_store.read();

            assert(
                role_store.has_role(keeper, role::FROZEN_ORDER_KEEPER),
                OrderError::INVALID_FROZEN_ORDER_KEEPER
            );
        }
    }
}
