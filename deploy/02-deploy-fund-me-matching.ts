import { networkConfig, developmentChains } from "../helper-hardhat-config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import verify from "../utils/verify"

const deployFundMeMatching: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    // @ts-ignore
    const { getNamedAccounts, deployments, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    let ethUsdPriceFeedAddress
    if (developmentChains.includes(network.name)) {
        const ethUsdAggregator = await deployments.get("MockV3Aggregator")
        ethUsdPriceFeedAddress = ethUsdAggregator.address
    } else {
        ethUsdPriceFeedAddress = networkConfig[network.name]["ethUsdPriceFeed"]
    }
    log("----------------------------------------------------")
    log("Deploying FundMeMatching and waiting for confirmations...")

    const args = [ethUsdPriceFeedAddress]
    const fundMeMatching = await deploy("FundMeMatching", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: networkConfig[network.name].blockConfirmations || 1,
    })
    log(`FundMeMatching deployed at ${fundMeMatching.address}`)

    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        await verify(fundMeMatching.address, args)
    }

    log("-------------------------------------------------")
}

export default deployFundMeMatching
deployFundMeMatching.tags = ["fundMeMatching"]
