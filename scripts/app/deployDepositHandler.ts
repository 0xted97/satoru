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
    const deposit_vault = contracts.find(e => e.name === "DepositVault")!;
    const event_emitter = contracts.find(e => e.name === "EventEmitter")!;
    const oracle = contracts.find(e => e.name === "Oracle")!;

    console.log("\n🚀 Deploying DepositHandler...")
    const compiledDepositHandlerCasm = json.parse(fs.readFileSync("./target/dev/satoru_DepositHandler.compiled_contract_class.json").toString("ascii"))
    const compiledDepositHandlerSierra = json.parse(fs.readFileSync("./target/dev/satoru_DepositHandler.contract_class.json").toString("ascii"))
    const depositHandlerCallData: CallData = new CallData(compiledDepositHandlerSierra.abi)
    const depositHandlerConstructor: Calldata = depositHandlerCallData.compile("constructor", {
        data_store_address: data_store.address,
        role_store_address: role_store.address,
        event_emitter_address: event_emitter.address,
        deposit_vault_address: deposit_vault.address,
        oracle_address: oracle.address,
    })
    const deployDepositHandlerResponse = await account0.declareAndDeploy({
        contract: compiledDepositHandlerSierra,
        casm: compiledDepositHandlerCasm,
        constructorCalldata: depositHandlerConstructor,
    })
    console.log("✅ DepositHandler Deployed:", deployDepositHandlerResponse.deploy.contract_address)

    const index = contracts.findIndex(e => e.name === "DepositHandler")!;
    contracts[index].address = deployDepositHandlerResponse.deploy.contract_address;
    
    fs.writeFileSync(contractsPath, JSON.stringify(contracts, null, 2));
}

deploy()