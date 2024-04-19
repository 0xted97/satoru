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
    deployedContracts.push({ name: "DeployingAccount", address: account0Address });

    const contractsPath = "./deployed_contracts.json";
    const contracts = JSON.parse(fs.readFileSync(contractsPath, "utf8")) as any[];
    
    const role_store = contracts.find(e => e.name === "RoleStore")!;
    const data_store = contracts.find(e => e.name === "DataStore")!;
    const order_handler = contracts.find(e => e.name === "OrderHandler")!;
    const deposit_handler = contracts.find(e => e.name === "DepositHandler")!;
    const withdrawal_handler = contracts.find(e => e.name === "WithdrawalHandler")!;
    const event_emitter = contracts.find(e => e.name === "EventEmitter")!;

    console.log("\n🚀 Deploying Router...")
    const compiledRouterCasm = json.parse(fs.readFileSync("./target/dev/satoru_Router.compiled_contract_class.json").toString("ascii"))
    const compiledRouterSierra = json.parse(fs.readFileSync("./target/dev/satoru_Router.contract_class.json").toString("ascii"))
    const routerCallData: CallData = new CallData(compiledRouterSierra.abi)
    const routerConstructor: Calldata = routerCallData.compile("constructor", {
        role_store_address: role_store.address,
    })
    const deployRouterResponse = await account0.declareAndDeploy({
        contract: compiledRouterSierra,
        casm: compiledRouterCasm,
        constructorCalldata: routerConstructor,
    })
    console.log("✅ Router Deployed:", deployRouterResponse.deploy.contract_address)

    console.log("\n🚀 Deploying ExchangeRouter...")
    const compiledExchangeRouterCasm = json.parse(fs.readFileSync("./target/dev/satoru_ExchangeRouter.compiled_contract_class.json").toString("ascii"))
    const compiledExchangeRouterSierra = json.parse(fs.readFileSync("./target/dev/satoru_ExchangeRouter.contract_class.json").toString("ascii"))
    const exchangeRouterCallData: CallData = new CallData(compiledExchangeRouterSierra.abi)
    const exchangeRouterConstructor: Calldata = exchangeRouterCallData.compile("constructor", {
        router_address: deployRouterResponse.deploy.contract_address,
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
    console.log("✅ ExchangeRouter Deployed:", deployExchangeRouterResponse.deploy.contract_address)

   
}

deploy()