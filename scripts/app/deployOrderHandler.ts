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
    const contracts = JSON.parse(fs.readFileSync(contractsPath, "utf8")) as {address: string, name: string}[];
    
    const role_store = contracts.find(e => e.name === "RoleStore")!;
    const data_store = contracts.find(e => e.name === "DataStore")!;
    const order_vault = contracts.find(e => e.name === "OrderVault")!;
    const event_emitter = contracts.find(e => e.name === "EventEmitter")!;
    const swap_handler = contracts.find(e => e.name === "SwapHandler")!;
    const referral_storages = contracts.find(e => e.name === "ReferralStorage")!;
    const oracle_store = contracts.find(e => e.name === "OracleStore")!;

    console.log("\n🚀 Deploying OrderHandler...")
    const compiledOrderHandlerCasm = json.parse(fs.readFileSync("./target/dev/satoru_OrderHandler.compiled_contract_class.json").toString("ascii"))
    const compiledOrderHandlerSierra = json.parse(fs.readFileSync("./target/dev/satoru_OrderHandler.contract_class.json").toString("ascii"))
    const orderHandlerCallData: CallData = new CallData(compiledOrderHandlerSierra.abi)
    const orderHandlerConstructor: Calldata = orderHandlerCallData.compile("constructor", {
        data_store_address: data_store.address,
        role_store_address: role_store.address,
        event_emitter_address: event_emitter.address,
        order_vault_address: order_vault.address,
        oracle_address: oracle_store.address,
        swap_handler_address: swap_handler.address,
        referral_storage_address: referral_storages.address
    })
    const deployOrderHandlerResponse = await account0.declareAndDeploy({
        contract: compiledOrderHandlerSierra,
        casm: compiledOrderHandlerCasm,
        constructorCalldata: orderHandlerConstructor,
    })
    console.log("✅ OrderHandler Deployed:", deployOrderHandlerResponse.deploy.contract_address)

    const index = contracts.findIndex(e => e.name === "OrderHandler")!;
    contracts[index].address = deployOrderHandlerResponse.deploy.contract_address;
    
    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 2));
}

deploy()