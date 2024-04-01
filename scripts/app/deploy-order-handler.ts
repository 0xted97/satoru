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

    console.log("\n🚀 Declaring OrderHandler...")
    const compiledOrderHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_OrderHandler.compiled_contract_class.json").toString("ascii"))
    const compiledOrderHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_OrderHandler.contract_class.json").toString("ascii"))
    const deployOrderHandlerResponse = await account0.declare({
        contract: compiledOrderHandlerSierra,
        casm: compiledOrderHandlerCasm,
    })
    console.log("✅ OrderHandler declare:", deployOrderHandlerResponse)

    // console.log("\n🚀 Declaring UpdateOrderHandler...")
    // const compiledUpdateOrderHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_UpdateOrderHandler.compiled_contract_class.json").toString("ascii"))
    // const compiledUpdateOrderHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_UpdateOrderHandler.contract_class.json").toString("ascii"))
    // const deployUpdateOrderHandlerResponse = await account0.declare({
    //     contract: compiledUpdateOrderHandlerSierra,
    //     casm: compiledUpdateOrderHandlerCasm,
    // })
    // console.log("✅ UpdateOrderHandler declare:", deployUpdateOrderHandlerResponse)

    // console.log("\n🚀 Declaring CreateOrderHandler...")
    // const compiledCreateOrderHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_CreateOrderHandler.compiled_contract_class.json").toString("ascii"))
    // const compiledCreateOrderHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_CreateOrderHandler.contract_class.json").toString("ascii"))
    // const deployCreateOrderHandlerResponse = await account0.declare({
    //     contract: compiledCreateOrderHandlerSierra,
    //     casm: compiledCreateOrderHandlerCasm,
    // })
    // console.log("✅ CreateOrderHandler declare:", deployCreateOrderHandlerResponse)

    // console.log("\n🚀 Declaring CancelOrderHandler...")
    // const compiledCancelOrderHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_CancelOrderHandler.compiled_contract_class.json").toString("ascii"))
    // const compiledCancelOrderHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_CancelOrderHandler.contract_class.json").toString("ascii"))
    // const deployCancelOrderHandlerResponse = await account0.declare({
    //     contract: compiledCancelOrderHandlerSierra,
    //     casm: compiledCancelOrderHandlerCasm,
    // })
    // console.log("✅ CancelOrderHandler declare:", deployCancelOrderHandlerResponse)

    // console.log("\n🚀 Declaring ExecuteOrderHandler...")
    // const compiledExecuteOrderHandlerCasm = json.parse(fs.readFileSync("../../target/dev/satoru_ExecuteOrderHandler.compiled_contract_class.json").toString("ascii"))
    // const compiledExecuteOrderHandlerSierra = json.parse(fs.readFileSync("../../target/dev/satoru_ExecuteOrderHandler.contract_class.json").toString("ascii"))
    // const deployExecuteOrderHandlerResponse = await account0.declare({
    //     contract: compiledExecuteOrderHandlerSierra,
    //     casm: compiledExecuteOrderHandlerCasm,
    // })
    // console.log("✅ ExecuteOrderHandler declare:", deployExecuteOrderHandlerResponse)
}

deploy()