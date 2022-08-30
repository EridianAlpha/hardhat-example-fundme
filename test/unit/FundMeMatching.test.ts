import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { assert, expect } from "chai"
import { BigNumber } from "ethers"
import { network, deployments, ethers } from "hardhat"
import { developmentChains } from "../../helper-hardhat-config"
import { FundMeMatching, MockV3Aggregator } from "../../typechain-types"

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("FundMeMatching", async function () {
          let fundMeMatching: FundMeMatching
          let deployer: SignerWithAddress
          let accounts: SignerWithAddress[]
          let mockV3Aggregator: MockV3Aggregator

          const initialFundingValue = ethers.utils.parseEther("10")

          beforeEach(async function () {
              accounts = await ethers.getSigners()
              deployer = accounts[0]
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
                  const funder2ConnectedContract =
                      fundMeMatching.connect(funder2)

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
                      endingFunder2FundedAmount
                          .sub(startingFunder2FundedAmount)
                          .toString(),
                      fundingAmount.toString()
                  )
              })
          })
      })
