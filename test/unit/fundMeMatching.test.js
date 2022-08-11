const { assert, expect } = require("chai")
const { developmentChains } = require("../../helper-hardhat-config")
const { deployments, ethers, getNamedAccounts } = require("hardhat")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("FundMeMatching", async function () {
          let fundMeMatching
          let deployer
          let mockV3Aggregator

          const sendValue = ethers.utils.parseEther("1")

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
          })

          describe("fund", async function () {
              it("Fails if you don't send enough ETH", async function () {
                  await expect(fundMeMatching.fund()).to.be.revertedWith(
                      "FundMe__NotEnoughEthSent"
                  )
              })
              it("Updates the amount funded data structure", async function () {
                  await fundMeMatching.fund({ value: sendValue })
                  const response =
                      await fundMeMatching.getAddressToAmountFunded(deployer)
                  assert.equal(response.toString(), sendValue.toString())
              })
              it("Adds funder to array of getFunderAddress", async function () {
                  await fundMeMatching.fund({ value: sendValue })
                  const funder = await fundMeMatching.getFunderAddress(0)
                  assert.equal(funder, deployer)
                  assert.equal(true, true)
              })
          })
      })
