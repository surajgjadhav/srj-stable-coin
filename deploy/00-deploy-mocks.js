const { network } = require("hardhat")
const {
    developmentChains,
    DECIMALS,
    ETH_USD_PRICE,
    BTC_USD_PRICE,
    INITIAL_BALANCE,
} = require("../helper-hardhat-config")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    if (developmentChains.includes(network.name)) {
        log("Local Network Detected! Deploying Mocks....")
        await deploy("MockV3AggregatorForEth", {
            contract: "MockV3Aggregator",
            from: deployer,
            args: [DECIMALS, ETH_USD_PRICE],
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })

        await deploy("MockV3AggregatorForBtc", {
            contract: "MockV3Aggregator",
            from: deployer,
            args: [DECIMALS, BTC_USD_PRICE],
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })

        await deploy("MockWeth", {
            contract: "ERC20Mock",
            from: deployer,
            args: ["Wrapped ETH", "WETH", deployer, INITIAL_BALANCE],
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })

        await deploy("MockWbtc", {
            contract: "ERC20Mock",
            from: deployer,
            args: ["Wrapped BTC", "WBTC", deployer, INITIAL_BALANCE],
            log: true,
            waitConfirmations: network.config.blockConfirmations || 1,
        })
        log("Mock Deployment Completed!")
    }
}

module.exports.tags = ["all", "mocks"]
