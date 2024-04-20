import { Account, hash, Contract, json, Calldata, CallData, RpcProvider, shortString } from "starknet"
import fs from 'fs'
import dotenv from 'dotenv'
// import { DeployedContract } from "../types";

dotenv.config()



async function deploy() {
    const deployedContracts: any[] = [];

    // connect provider
    const providerUrl = process.env.PROVIDER_URL
    const provider = new RpcProvider({ nodeUrl: providerUrl! })

    // connect your account. To adapt to your own account :
    const privateKey0: string = process.env.ACCOUNT_PRIVATE as string
    const account0Address: string = process.env.ACCOUNT_PUBLIC as string
    const account0 = new Account(provider, account0Address!, privateKey0!)
    console.log("\n📦 Deploying with Account: " + account0Address)

    const contractsPath = "./deployed_contracts.json";
    const contracts = JSON.parse(fs.readFileSync(contractsPath, "utf8")) as {address: string, name: string}[];
    
    const router = contracts.find(e => e.name === "Router")!;
    const role_store = contracts.find(e => e.name === "RoleStore")!;
    const data_store = contracts.find(e => e.name === "DataStore")!;
    const event_emitter = contracts.find(e => e.name === "EventEmitter")!;
    const deposit_handler = contracts.find(e => e.name === "DepositHandler")!;
    const order_handler = contracts.find(e => e.name === "OrderHandler")!;
    const withdrawal_handler = contracts.find(e => e.name === "WithdrawalHandler")!;
    const referral_storages = contracts.find(e => e.name === "ReferralStorage")!;
    const oracle_store = contracts.find(e => e.name === "OracleStore")!;

    console.log("\n🚀 Deploying ExchangeRouter...")
    const compiledExchangeRouterCasm = json.parse(fs.readFileSync("./target/dev/satoru_ExchangeRouter.compiled_contract_class.json").toString("ascii"))
    const compiledExchangeRouterSierra = json.parse(fs.readFileSync("./target/dev/satoru_ExchangeRouter.contract_class.json").toString("ascii"))
    const exchangeRouterCallData: CallData = new CallData(compiledExchangeRouterSierra.abi)
    const exchangeRouterConstructor: Calldata = exchangeRouterCallData.compile("constructor", {
        router_address: router.address,
        data_store_address: data_store.address,
        role_store_address: role_store.address,
        event_emitter_address: event_emitter.address,
        deposit_handler_address: deposit_handler.address,
        withdrawal_handler_address: withdrawal_handler.address,
        order_handler_address: order_handler.address,
    })
    const deployExchangeRouterResponse = await account0.declareAndDeploy({
        contract: compiledExchangeRouterSierra,
        casm: compiledExchangeRouterCasm,
        constructorCalldata: exchangeRouterConstructor,
    })
    console.log("✅ ExchangeRouter Deployed:", deployExchangeRouterResponse.deploy.contract_address);

    const index = contracts.findIndex(e => e.name === "ExchangeRouter")!;
    contracts[index].address = deployExchangeRouterResponse.deploy.contract_address;
    
    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 2));
    

   
}

deploy()