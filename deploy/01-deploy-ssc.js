const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    log("Deploying Srj Stable Coin....")
    await deploy("SrjStableCoin", {
        from: deployer,
        args: [],
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
    log("Deployment completed")
}

module.exports.tags = ["all", "ssc"]
