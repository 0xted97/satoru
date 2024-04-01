import { Account, hash, Contract, json, Calldata, CallData, RpcProvider, shortString } from "starknet"
import fs from 'fs'
import dotenv from 'dotenv'

dotenv.config()

async function deploy() {
    // connect provider
    const providerUrl = process.env.PROVIDER_URL
    const provider = new RpcProvider({ nodeUrl: providerUrl! })

    // connect your account. To adapt to your own account :
    const privateKey0: string = process.env.ACCOUNT_PRIVATE as string
    console.log("privateKey0", privateKey0);
    const account0Address: string = process.env.ACCOUNT_PUBLIC as string
    console.log("account0Address", account0Address);
    const account0 = new Account(provider, account0Address!, privateKey0!)
    console.log("\n📦 Declaring with Account: " + account0Address)

    console.log("\n🚀 Declaring LiquidationHandler...")
    const compiledLiquidationHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_LiquidationHandler.compiled_contract_class.json").toString("ascii"))
    const compiledLiquidationHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_LiquidationHandler.contract_class.json").toString("ascii"))
    const deployLiquidationHandlerResponse = await account0.declare({
        contract: compiledLiquidationHandlerSierra,
        casm: compiledLiquidationHandlerCasm,
    })
    console.log("✅ LiquidationHandler declare:", deployLiquidationHandlerResponse)
}

deploy()