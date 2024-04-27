// *************************************************************************
//                                  IMPORTS
// *************************************************************************

// Core lib imports.
use starknet::{ContractAddress, contract_address_const};
use clone::Clone;
use debug::PrintTrait;
// Local imports.
use satoru::order::base_order_utils::{ExecuteOrderParams, CreateOrderParams};
use satoru::order::base_order_utils;
use satoru::data::data_store::{IDataStoreDispatcher, IDataStoreDispatcherTrait};
use satoru::event::event_emitter::{IEventEmitterDispatcher, IEventEmitterDispatcherTrait};
use satoru::order::order_vault::{IOrderVaultDispatcher, IOrderVaultDispatcherTrait};
use satoru::mock::referral_storage::{IReferralStorageDispatcher, IReferralStorageDispatcherTrait};
use satoru::market::market_utils;
use satoru::nonce::nonce_utils;
use satoru::utils::account_utils;
use satoru::referral::referral_utils;
use satoru::token::token_utils;
use satoru::callback::callback_utils;
use satoru::gas::gas_utils;
use satoru::order::order::{Order, OrderType, OrderTrait};
use satoru::event::event_utils::{
    LogData, LogDataTrait, Felt252IntoContractAddress, ContractAddressDictValue, I256252DictValue
};
use satoru::utils::serializable_dict::{SerializableFelt252Dict, SerializableFelt252DictTrait};
use satoru::order::error::OrderError;

// Ted
// use satoru::order::{increase_order_utils, decrease_order_utils, swap_order_utils};
use satoru::order::liquidation::{liquidation_decrease_order_utils};

use satoru::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


/// Executes an order.
/// # Arguments
/// * `params` - The parameters used to execute the order.
fn execute_order(params: ExecuteOrderParams) {
    // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
    // TODO GAS NOT AVAILABLE params.startingGas -= gasleft() / 63;
    params.contracts.data_store.remove_order(params.key, params.order.account);

    '5. Execute Order'.print();

    // let balance_ETH_start = IERC20Dispatcher { contract_address: contract_address_const::<'ETH'>() }
    //     .balance_of(contract_address_const::<'caller'>());

    // let balance_USDC_start = IERC20Dispatcher {
    //     contract_address: contract_address_const::<'USDC'>()
    // }
    //     .balance_of(contract_address_const::<'caller'>());

    // '5. eth start create order'.print();
    // balance_ETH_start.print();

    // '5. usdc start create order'.print();
    // balance_USDC_start.print();

    base_order_utils::validate_non_empty_order(@params.order);

    base_order_utils::validate_order_trigger_price(
        params.contracts.oracle,
        params.market.index_token,
        params.order.order_type,
        params.order.trigger_price,
        params.order.is_long
    );
    'passed validations'.print();
    let params_process = ExecuteOrderParams {
        contracts: params.contracts,
        key: params.key,
        order: params.order,
        swap_path_markets: params.swap_path_markets.clone(),
        min_oracle_block_numbers: params.min_oracle_block_numbers.clone(),
        max_oracle_block_numbers: params.max_oracle_block_numbers.clone(),
        market: params.market,
        keeper: params.keeper,
        starting_gas: params.starting_gas,
        secondary_order_type: params.secondary_order_type
    };

    let mut event_data: LogData = process_order(params_process);
    // validate that internal state changes are correct before calling
    // external callbacks
    // if the native token was transferred to the receiver in a swap
    // it may be possible to invoke external contracts before the validations
    // are called

    // let balance_ETH_after = IERC20Dispatcher { contract_address: contract_address_const::<'ETH'>() }
    //     .balance_of(contract_address_const::<'caller'>());
    // 'balance_ETH_after'.print();
    // balance_ETH_after.print();

    // let balance_USDC_after = IERC20Dispatcher {
    //     contract_address: contract_address_const::<'USDC'>()
    // }
    //     .balance_of(contract_address_const::<'caller'>());
    // 'balance_USDC_after'.print();
    // balance_USDC_after.print();

    if (params.market.market_token != contract_address_const::<0>()) {
        market_utils::validate_market_token_balance_check(
            params.contracts.data_store, params.market
        );
    }
    market_utils::validate_market_token_balance_array(
        params.contracts.data_store, params.swap_path_markets
    );

    params.contracts.event_emitter.emit_order_executed(params.key, params.secondary_order_type);
// callback_utils::after_order_execution(params.key, params.order, event_data);

// the order.executionFee for liquidation / adl orders is zero
// gas costs for liquidations / adl is subsidised by the treasury
// TODO crashing
// gas_utils::pay_execution_fee_order(
//     params.contracts.data_store,
//     params.contracts.event_emitter,
//     params.contracts.order_vault,
//     params.order.execution_fee,
//     params.starting_gas,
//     params.keeper,
//     params.order.account
// );
}

/// Process an order execution.
/// # Arguments
/// * `params` - The parameters used to process the order.
fn process_order(params: ExecuteOrderParams) -> LogData {
    if (base_order_utils::is_decrease_order(params.order.order_type)) {
        return liquidation_decrease_order_utils::process_order(params);
    }
    panic_with_felt252(OrderError::UNSUPPORTED_ORDER_TYPE)
}

/// Cancels an order.
/// # Arguments
/// * `data_store` - The `DataStore` contract dispatcher.
/// * `event_emitter` - The `EventEmitter` contract dispatcher.
/// * `order_vault` - The `OrderVault` contract dispatcher.
/// * `key` - The key of the order to cancel
/// * `keeper` - The keeper sending the transaction.
/// * `starting_gas` - The starting gas of the transaction.
/// * `reason` - The reason for cancellation.
/// # Returns
/// Return the key of the created order.
fn cancel_order(
    data_store: IDataStoreDispatcher,
    event_emitter: IEventEmitterDispatcher,
    order_vault: IOrderVaultDispatcher,
    key: felt252,
    keeper: ContractAddress,
    starting_gas: u256,
    reason: felt252,
    reason_bytes: Array<felt252>
) {
    // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
    // starting_gas -= gas_left() / 63;

    let order = data_store.get_order(key);
    base_order_utils::validate_non_empty_order(@order);

    data_store.remove_order(key, order.account);

    if (base_order_utils::is_increase_order(order.order_type)
        || base_order_utils::is_swap_order(order.order_type)) {
        if (order.initial_collateral_delta_amount > 0) {
            order_vault
                .transfer_out(
                    order.initial_collateral_token,
                    order.account,
                    order.initial_collateral_delta_amount,
                );
        }
    }

    event_emitter.emit_order_cancelled(key, reason, reason_bytes.span());

    let mut event_data: LogData = Default::default();
    callback_utils::after_order_cancellation(key, order, event_data);

    gas_utils::pay_execution_fee_order(
        data_store,
        event_emitter,
        order_vault,
        order.execution_fee,
        starting_gas,
        keeper,
        order.account
    );
}

/// Freezes an order.
/// # Arguments
/// * `data_store` - The `DataStore` contract dispatcher.
/// * `event_emitter` - The `EventEmitter` contract dispatcher.
/// * `order_vault` - The `OrderVault` contract dispatcher.
/// * `key` - The key of the order to freeze
/// * `keeper` - The keeper sending the transaction.
/// * `starting_gas` - The starting gas of the transaction.
/// * `reason` - The reason the order was frozen.
/// # Returns
/// Return the key of the created order.
fn freeze_order(
    data_store: IDataStoreDispatcher,
    event_emitter: IEventEmitterDispatcher,
    order_vault: IOrderVaultDispatcher,
    key: felt252,
    keeper: ContractAddress,
    starting_gas: u256,
    reason: felt252,
    reason_bytes: Array<felt252>
) {
    // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
    // startingGas -= gas_left() / 63;

    let mut order = data_store.get_order(key);
    base_order_utils::validate_non_empty_order(@order);

    if (order.is_frozen) {
        panic_with_felt252(OrderError::ORDER_ALREADY_FROZEN)
    }

    let execution_fee = order.execution_fee;

    order.execution_fee = 0;
    order.is_frozen = true;
    data_store.set_order(key, order);

    event_emitter.emit_order_frozen(key, reason, reason_bytes.span());

    let mut event_data: LogData = Default::default();
    callback_utils::after_order_frozen(key, order, event_data);

    gas_utils::pay_execution_fee_order(
        data_store, event_emitter, order_vault, execution_fee, starting_gas, keeper, order.account
    );
}
