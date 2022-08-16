const { assert, expect } = require("chai")
const { developmentChains } = require("../../helper-hardhat-config")
const { deployments, ethers, getNamedAccounts } = require("hardhat")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("FundMeMatching", async function () {
          let fundMeMatching
          let deployer
          let mockV3Aggregator

          const initialFundingValue = ethers.utils.parseEther("10")

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["fundMeMatching", "mocks"])
              fundMeMatching = await ethers.getContract(
                  "FundMeMatching",
                  deployer
              )
              mockV3Aggregator = await ethers.getContract(
                  "MockV3Aggregator",
                  deployer
              )
              await fundMeMatching.initialFunding({
                  value: ethers.utils.parseEther("10"),
              })
          })

          describe("fund", async function () {
              // Initializes the FundMeMatching contract with 10 ETH
              it("Initial funding check", async function () {
                  const balance = await fundMeMatching.provider.getBalance(
                      fundMeMatching.address
                  )

                  assert.equal(
                      balance.toString(),
                      initialFundingValue.toString()
                  )
              })

              it("Updates the amount funded data structure", async function () {
                  const fundingAmount = ethers.utils.parseEther("1")

                  const accounts = await ethers.getSigners()
                  const funder2 = accounts[1]
                  const funder2ConnectedContract = await fundMeMatching.connect(
                      funder2
                  )

                  const startingFunder2FundedAmount =
                      await fundMeMatching.getAddressToAmountFunded(
                          funder2.address
                      )

                  // Send funding amount
                  await funder2ConnectedContract.fund({
                      value: fundingAmount,
                  })

                  const endingFunder2FundedAmount =
                      await fundMeMatching.getAddressToAmountFunded(
                          funder2.address
                      )

                  assert.equal(
                      (
                          endingFunder2FundedAmount -
                          startingFunder2FundedAmount
                      ).toString(),
                      fundingAmount.toString()
                  )
              })
          })
      })
