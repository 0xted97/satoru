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
    const abisPath = "./abis/";
    const contracts = JSON.parse(fs.readFileSync(contractsPath, "utf8")) as {address: string, name: string}[];

    const contractsToDeploy = contracts.filter((contract: any) => contract.address);

    for await (const contract of contractsToDeploy) {
        const { abi } = await account0.getClassAt(contract.address);
        console.log("🚀 ~ deploy ~ abi:", abi)
        const contractInstance = new Contract(abi, contract.address, account0);
        deployedContracts.push({ name: contract.name, address: contract.address });
        const contractAbi = JSON.stringify(abi, null, 2);
        fs.writeFileSync(abisPath + contract.name + ".json", contractAbi);
    }





}

deploy()