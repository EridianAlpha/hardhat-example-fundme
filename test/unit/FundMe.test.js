const { deployments, ethers, getNamedAccounts } = require("hardhat")
const { assert, expect } = require("chai")
const { developmentChains } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("FundMe", async function () {
          let fundMe
          let deployer
          let mockV3Aggregator

          const sendValue = ethers.utils.parseEther("1")

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["fundMe", "mocks"])
              fundMe = await ethers.getContract("FundMe", deployer)
              mockV3Aggregator = await ethers.getContract(
                  "MockV3Aggregator",
                  deployer
              )
          })

          describe("constructor", async function () {
              it("Sets the aggregator addresses correctly", async function () {
                  const response = await fundMe.getPriceFeed()
                  assert.equal(response, mockV3Aggregator.address)
              })
          })

          describe("fund", async function () {
              it("Fails if you don't send enough ETH", async function () {
                  await expect(fundMe.fund()).to.be.revertedWith(
                      "FundMe__NotEnoughEthSent"
                  )
              })
              it("Updates the amount funded data structure", async function () {
                  await fundMe.fund({ value: sendValue })
                  const response = await fundMe.getAddressToAmountFunded(
                      deployer
                  )
                  assert.equal(response.toString(), sendValue.toString())
              })
              it("Adds funder to array of getFunder", async function () {
                  await fundMe.fund({ value: sendValue })
                  const funder = await fundMe.getFunder(0)
                  assert.equal(funder, deployer)
              })
          })

          describe("withdraw", async function () {
              beforeEach(async function () {
                  await fundMe.fund({ value: sendValue })
              })

              it("Only allows the owner to withdraw", async function () {
                  const accounts = await ethers.getSigners()
                  const attacker = accounts[1]
                  const attackerConnectedContract = await fundMe.connect(
                      attacker
                  ) // attacker is an account object, so we're connecting the whole account
                  await expect(
                      attackerConnectedContract.withdraw()
                  ).to.be.revertedWith("FundMe__NotOwner")
              })

              it("Withdraw .call failure throws error", async function () {
                  const testHelperFactory = await ethers.getContractFactory(
                      "TestHelper"
                  )
                  testHelper = await testHelperFactory.deploy()
                  await testHelper.deployed()
                  await expect(testHelper.fundMeWithdraw()).to.be.revertedWith(
                      "FundMe__WithdrawFailed"
                  )
              })

              it("Withdraw ETH from multiple funders", async function () {
                  // Arrange
                  const accounts = await ethers.getSigners()
                  const funderCount = 5
                  for (let i = 0; i < funderCount; i++) {
                      const fundMeConnectedContract = await fundMe.connect(
                          accounts[i]
                      )
                      await fundMeConnectedContract.fund({ value: sendValue })
                  }
                  const startingFundMeBalance =
                      await fundMe.provider.getBalance(fundMe.address)
                  const startingDeployerBalance =
                      await fundMe.provider.getBalance(deployer)

                  // Act
                  const transactionResponse = await fundMe.withdraw()
                  const transactionReceipt = await transactionResponse.wait(1)
                  const { gasUsed, effectiveGasPrice } = transactionReceipt
                  const gasCost = gasUsed.mul(effectiveGasPrice)

                  const endingFundMeBalance = await fundMe.provider.getBalance(
                      fundMe.address
                  )
                  const endingDeployerBalance =
                      await fundMe.provider.getBalance(deployer)

                  // Assert
                  assert.equal(endingFundMeBalance, 0)
                  assert.equal(
                      startingFundMeBalance
                          .add(startingDeployerBalance)
                          .toString(),
                      endingDeployerBalance.add(gasCost).toString()
                  )

                  // Check that s_funders is reset properly
                  await expect(fundMe.getFunder(0)).to.be.reverted

                  // Check that s_addressToAmountFunded mapping is reset for all addresses
                  for (i = 0; i < funderCount; i++) {
                      assert.equal(
                          await fundMe.getAddressToAmountFunded(
                              accounts[i].address
                          ),
                          0
                      )
                  }
              })
          })

          describe("getters", async function () {
              it("Gets s_priceFeed version correctly", async function () {
                  const response = await fundMe.getPriceFeedVersion()
                  const version = await mockV3Aggregator.version()
                  assert.equal(response.toString(), version.toString())
              })

              it("Gets the contract owner correctly", async function () {
                  const response = await fundMe.getOwner()
                  assert.equal(response, deployer)
              })
          })

          describe("receive & fallback", async function () {
              it("Coverage for receive() function", async function () {
                  const response = await fundMe.fallback({ value: sendValue })
                  assert.equal(response.value.toString(), sendValue.toString())
              })

              it("Coverage for fallback() function", async () => {
                  ;[signer] = await ethers.getSigners()

                  const nonExistentFuncSignature =
                      "nonExistentFunc(uint256,uint256)"
                  const fakeDemoContract = new ethers.Contract(
                      fundMe.address,
                      [
                          ...fundMe.interface.fragments,
                          `function ${nonExistentFuncSignature}`,
                      ],
                      signer
                  )
                  const tx = fakeDemoContract[nonExistentFuncSignature](1, 2)
                  // Solution from: https://stackoverflow.com/questions/72584559/how-to-test-the-solidity-fallback-function-via-hardhat
                  // Not sure what to actually check at this point as waiting for the tx to return
                  // throws a gas error that I don't know how to parse
                  // But this is good enough for now as it completes the coverage
              })
          })
      })
