const { network, ethers } = require("hardhat")
const { developmentChains, netWorkConfig } = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    let ethUsdPriceFeedAddress, btcUsdPriceFeedAddress, wethAddress, wbtcAddress
    if (developmentChains.includes(network.name)) {
        const ethUsdPriceFeed = await deployments.get("MockV3AggregatorForEth")
        ethUsdPriceFeedAddress = ethUsdPriceFeed.address

        const btcUsdPriceFeed = await deployments.get("MockV3AggregatorForBtc")
        btcUsdPriceFeedAddress = btcUsdPriceFeed.address

        const weth = await deployments.get("MockWeth")
        wethAddress = weth.address

        const wbtc = await deployments.get("MockWbtc")
        wbtcAddress = wbtc.address
    } else {
        ethUsdPriceFeedAddress =
            netWorkConfig[chainId]["ethUsdPriceFeedAddress"]
        btcUsdPriceFeedAddress =
            netWorkConfig[chainId]["btcUsdPriceFeedAddress"]
        wethAddress = netWorkConfig[chainId]["wethAddress"]
        wbtcAddress = netWorkConfig[chainId]["wbtcAddress"]
    }

    const ssc = await deployments.get("SrjStableCoin")

    const args = [
        [wethAddress, wbtcAddress],
        [ethUsdPriceFeedAddress, btcUsdPriceFeedAddress],
        ssc.address,
    ]

    log("Deploying SSC Engine...")
    const sscEngine = await deploy("SSCEngine", {
        from: deployer,
        log: true,
        args: args,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY
    ) {
        await verify(sscEngine, args)
    }
    log("Deployment Completed!")
}

module.exports.tags = ["all", "sscEngine"]
