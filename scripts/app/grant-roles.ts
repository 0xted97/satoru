import { Account, RpcProvider, Call } from "starknet"
import fs from 'fs'
import dotenv from 'dotenv'
import { RoleKeys } from "./utils";

dotenv.config()

async function grant_roles() {
    // connect provider
    const providerUrl = process.env.PROVIDER_URL
    const provider = new RpcProvider({ nodeUrl: providerUrl! })

    // connect your account. To adapt to your own account :
    const privateKey0: string = process.env.ACCOUNT_PRIVATE as string
    const account0Address: string = process.env.ACCOUNT_PUBLIC as string
    const account0 = new Account(provider, account0Address!, privateKey0!)

    const contractsPath = "./deployed_contracts.json";
    const contracts = JSON.parse(fs.readFileSync(contractsPath, "utf8")) as any[];

    const role_store = contracts.find(e => e.name === "RoleStore")!;
    const exchange_router = contracts.find(e => e.name === "ExchangeRouter")!;
    const router = contracts.find(e => e.name === "Router")!;
    const order_handler = contracts.find(e => e.name === "OrderHandler")!;
    const deposit_handler = contracts.find(e => e.name === "DepositHandler")!;
    const withdrawal_handler = contracts.find(e => e.name === "WithdrawalHandler")!;
    const market_factory = contracts.find(e => e.name === "MarketFactory")!;
    
    const grantRolesCalldata: Call[] = [
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                "0x6b86e40118f29ebe393a75469b4d926c7a44c2e2681b6d319520b7c1156d114",
                RoleKeys.ADMIN,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                account0.address,
                RoleKeys.ADMIN,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                account0.address,
                RoleKeys.ROLE_ADMIN,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                order_handler?.address,
                RoleKeys.CONTROLLER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                exchange_router.address,
                RoleKeys.CONTROLLER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                market_factory.address,
                RoleKeys.CONTROLLER,
            ]
        },

        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                deposit_handler.address,
                RoleKeys.CONTROLLER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                order_handler.address,
                RoleKeys.CONTROLLER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                withdrawal_handler.address,
                RoleKeys.CONTROLLER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                account0.address,
                RoleKeys.MARKET_KEEPER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                market_factory.address,
                RoleKeys.MARKET_KEEPER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                account0.address,
                RoleKeys.ORDER_KEEPER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                account0.address,
                RoleKeys.FROZEN_ORDER_KEEPER,
            ]
        },
        {
            contractAddress: role_store?.address,
            entrypoint: "grant_role",
            calldata: [
                exchange_router.address,
                RoleKeys.ROUTER_PLUGIN,
            ]
        },
    ];

    const tx = await account0.execute(grantRolesCalldata);
    console.log("✅ Grant roles successfully: ", tx.transaction_hash)
}

grant_roles()