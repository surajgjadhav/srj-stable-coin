const { assert, expect } = require("chai")
const { Contract } = require("ethers")
const { deployments, ethers, getNamedAccounts } = require("hardhat")

describe("SSCEngine", function () {
    let sscEngine,
        sscEngineAddress,
        deployer,
        ssc,
        sscAddress,
        mockV3AggregatorForEth,
        mockV3AggregatorForBtc,
        mockWeth,
        mockWethAddress,
        mockWbtc,
        mockWbtcAddress
    const AMOUNT_COLLATERAL = ethers.parseEther("10")
    const STARTING_ERC20_BALANCE = ethers.parseEther("20")
    beforeEach(async function () {
        // deploy our SSCEngine Contract
        // using hardhat deploy
        deployer = (await getNamedAccounts()).deployer
        await deployments.fixture(["all"])
        sscEngine = await ethers.getContract("SSCEngine", deployer)
        ssc = await ethers.getContract("SrjStableCoin", deployer)
        sscAddress = await ssc.getAddress()
        sscEngineAddress = await sscEngine.getAddress()

        await ssc.transferOwnership(sscEngineAddress)

        mockV3AggregatorForEth = await ethers.getContract(
            "MockV3AggregatorForEth",
            deployer,
        )
        mockV3AggregatorForBtc = await ethers.getContract(
            "MockV3AggregatorForBtc",
            deployer,
        )

        mockWeth = await ethers.getContract("MockWeth", deployer)
        await mockWeth.mint(deployer, STARTING_ERC20_BALANCE)
        mockWethAddress = await mockWeth.getAddress()

        mockWbtc = await ethers.getContract("MockWbtc", deployer)
        await mockWbtc.mint(deployer, STARTING_ERC20_BALANCE)
        mockWbtcAddress = await mockWbtc.getAddress()
    })

    describe("constructor", function () {
        it("sets ssc address correctly", async function () {
            const sscAddressReturned = await sscEngine.getSscAddress()
            assert.equal(sscAddress, sscAddressReturned)
        })

        it("sets Collateral Token address correctly", async function () {
            const tokenAddresses = await sscEngine.getCollateralTokens()
            assert.equal(tokenAddresses[0], mockWethAddress)
            assert.equal(tokenAddresses[1], mockWbtcAddress)
        })

        it("sets Price Feed address correctly", async function () {
            const MockV3AggregatorAddressForEth =
                await mockV3AggregatorForEth.getAddress()
            const MockV3AggregatorAddressForBtc =
                await mockV3AggregatorForBtc.getAddress()

            const ethPriceFeedAddresses = await sscEngine.getTokenPriceFeed(
                mockWethAddress,
            )
            const btcPriceFeedAddresses = await sscEngine.getTokenPriceFeed(
                mockWbtcAddress,
            )

            assert.equal(ethPriceFeedAddresses, MockV3AggregatorAddressForEth)
            assert.equal(btcPriceFeedAddresses, MockV3AggregatorAddressForBtc)
        })
    })

    describe("depositCollateral", function () {
        it("revert if deposit amount is less that or equal to zero", async function () {
            await expect(sscEngine.depositCollateral(mockWethAddress, 0)).to.be
                .reverted
        })

        it("revert for invalid token deposit", async function () {
            await expect(sscEngine.depositCollateral(sscAddress, 0)).to.be
                .reverted
        })

        it("deposit collateral successfully", async function () {
            await mockWeth.approve(sscEngineAddress, AMOUNT_COLLATERAL)
            await sscEngine.depositCollateral(
                mockWethAddress,
                AMOUNT_COLLATERAL,
            )
            const depositedAmount = await sscEngine.getCollateralBalanceOfUser(
                deployer,
                mockWethAddress,
            )
            assert.equal(depositedAmount, AMOUNT_COLLATERAL)
        })
    })

    describe("mintSsc", function () {
        beforeEach(async function () {
            await mockWeth.approve(sscEngineAddress, AMOUNT_COLLATERAL)
            await sscEngine.depositCollateral(
                mockWethAddress,
                AMOUNT_COLLATERAL,
            )
        })
        it("revert if minting in case of bad health", async function () {
            const amount = await sscEngine.getCollateralAmountInUsd(deployer)
            await expect(sscEngine.mintSsc(amount)).to.be.reverted
        })
        it("mint SSC successfully", async function () {
            const mintedAmountExpected = await sscEngine.getUsdAmountFromToken(
                mockWethAddress,
                ethers.parseEther("2"),
            )
            await sscEngine.mintSsc(mintedAmountExpected)
            const mintedAmount = await sscEngine.getMintedSscCount(deployer)
            assert.equal(mintedAmount, mintedAmountExpected)
        })
    })

    describe("burnSsc", function () {
        beforeEach(async function () {
            await mockWeth.approve(sscEngineAddress, AMOUNT_COLLATERAL)
            await sscEngine.depositCollateral(
                mockWethAddress,
                AMOUNT_COLLATERAL,
            )
            const mintedAmount = await sscEngine.getUsdAmountFromToken(
                mockWethAddress,
                ethers.parseEther("2"),
            )
            await sscEngine.mintSsc(mintedAmount)
            await ssc.approve(sscEngineAddress, mintedAmount)
        })

        it("revert if burn amount is less than or equal to zero", async function () {
            await expect(sscEngine.burnSsc(0)).to.be.reverted
        })

        it("sets mintedSSC count correctly after burn", async function () {
            const burnAmount = await sscEngine.getUsdAmountFromToken(
                mockWethAddress,
                ethers.parseEther("2"),
            )
            await sscEngine.burnSsc(burnAmount)
            const mintedSscCount = await sscEngine.getMintedSscCount(deployer)
            assert.equal(mintedSscCount, 0)
        })
    })

    describe("redeemCollateral", function () {
        beforeEach(async function () {
            await mockWeth.approve(sscEngineAddress, AMOUNT_COLLATERAL)
            await sscEngine.depositCollateral(
                mockWethAddress,
                AMOUNT_COLLATERAL,
            )
        })

        it("revert if redeem amount is less than or equal to zero", async function () {
            await expect(sscEngine.redeemCollateral(mockWethAddress, 0)).to.be
                .reverted
        })

        it("revert if affecting health factor", async function () {
            const mintedAmount = await sscEngine.getUsdAmountFromToken(
                mockWethAddress,
                ethers.parseEther("2"),
            )
            await sscEngine.mintSsc(mintedAmount)
            await ssc.approve(sscEngineAddress, mintedAmount)

            await expect(
                sscEngine.redeemCollateral(mockWethAddress, AMOUNT_COLLATERAL),
            ).to.be.reverted
        })

        it("redeem collateral Successfully", async function () {
            const mintedAmount = await sscEngine.getUsdAmountFromToken(
                mockWethAddress,
                ethers.parseEther("2"),
            )
            await sscEngine.mintSsc(mintedAmount)
            await ssc.approve(sscEngineAddress, mintedAmount)
            const redeemAmount = ethers.parseEther("1")

            await sscEngine.redeemCollateral(mockWethAddress, redeemAmount)
            const remainingCollateral =
                await sscEngine.getCollateralBalanceOfUser(
                    deployer,
                    mockWethAddress,
                )

            assert.equal(remainingCollateral + redeemAmount, AMOUNT_COLLATERAL)
        })
    })
})
