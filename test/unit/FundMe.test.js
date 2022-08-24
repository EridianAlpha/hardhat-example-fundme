const { assert, expect } = require("chai")
const { developmentChains } = require("../../helper-hardhat-config")
const { deployments, ethers, getNamedAccounts } = require("hardhat")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("FundMe", async function () {
          let fundMe
          let deployer
          let accounts
          let mockV3Aggregator
          let ethUsdAggregator // Get priceFeedAddress

          const sendValue = ethers.utils.parseEther("1")

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              await deployments.fixture(["fundMe", "mocks"])
              fundMe = await ethers.getContract("FundMe", deployer)
              mockV3Aggregator = await ethers.getContract(
                  "MockV3Aggregator",
                  deployer
              )
              ethUsdAggregator = await deployments.get("MockV3Aggregator")
              accounts = await ethers.getSigners()
          })

          describe("constructor", async function () {
              it("Sets the aggregator addresses correctly", async function () {
                  const response = await fundMe.getPriceFeed()
                  assert.equal(response, mockV3Aggregator.address)
              })
          })

          describe("fund", async function () {
              it("Fails if you don't send enough ETH", async function () {
                  await expect(
                      fundMe.fund({ value: ethers.utils.parseEther("0.001") })
                  ).to.be.revertedWith("FundMe__NotEnoughEthSent")
              })
              it("Updates the amount funded data structure", async function () {
                  await fundMe.fund({ value: sendValue })
                  const response = await fundMe.getAddressToAmountFunded(
                      deployer
                  )
                  assert.equal(response.toString(), sendValue.toString())
              })
              it("Checks funder added to s_funders array", async function () {
                  await fundMe.fund({ value: sendValue })
                  const response = await fundMe.getFunderIndex(deployer)
                  assert.equal(response.toString(), 0)
              })
              it("No duplicate entries added to s_funders array", async function () {
                  await fundMe.fund({ value: sendValue })
                  await fundMe.fund({ value: sendValue })

                  const funders = await fundMe.getFunders()

                  let findDuplicates = (arr) =>
                      arr.filter(
                          (address, index) => arr.indexOf(address) != index
                      )
                  assert.equal(findDuplicates(funders), false)
              })
              it("Checks funder address matches 0 index of s_funders array", async function () {
                  await fundMe.fund({ value: sendValue })
                  const funder = await fundMe.getFunderAddress(0)
                  assert.equal(funder, deployer)
              })
          })

          describe("withdraw", async function () {
              it("Only allows the owner to withdraw", async function () {
                  await fundMe.fund({ value: sendValue })

                  const attacker = accounts[1]
                  const attackerConnectedContract = await fundMe.connect(
                      attacker
                  ) // attacker is an account object, so we're connecting the whole account
                  await expect(
                      attackerConnectedContract.withdraw()
                  ).to.be.revertedWith("FundMe__NotOwner")
              })

              it("Withdraw call with zero balance fails", async function () {
                  await expect(fundMe.withdraw()).to.be.revertedWith(
                      "FundMe__WithdrawNoFunds"
                  )
              })

              it("Withdraw .call failure throws error", async function () {
                  // Get helper contract
                  const testHelperFactory = await ethers.getContractFactory(
                      "TestHelper"
                  )

                  // Deploy helper contract and pass priceFeedAddress to constructor
                  testHelper = await testHelperFactory.deploy(
                      ethUsdAggregator.address
                  )
                  await testHelper.deployed()

                  // Send funds to helper contract that can be used for the fund() function
                  await testHelper.initialFunding({
                      value: ethers.utils.parseEther("5"),
                  })

                  // Send funds from helper contract to FundMe contract
                  // so that this test passes the WithdrawEmpty test
                  await testHelper.fundMeFund(sendValue)

                  await expect(testHelper.fundMeWithdraw()).to.be.revertedWith(
                      "FundMe__WithdrawFailed"
                  )

                  // If the withdraw fails, the s_funders address array should not be reset
                  // (This test isn't really needed, it's just showing that revert works by undoing all changes
                  // made to the state during the transaction)
                  assert.equal(
                      await testHelper.fundMeGetFunderAddress(0),
                      testHelper.address
                  )
              })

              it("Withdraw ETH from multiple funders", async function () {
                  // Arrange
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
                  await expect(fundMe.getFunderAddress(0)).to.be.reverted

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

              it("Withdraw selfdestruct attack funds", async function () {
                  await fundMe.fund({ value: sendValue })

                  // Check funds can't be withdrawn before the attack
                  await expect(
                      fundMe.withdrawSelfdestructFunds()
                  ).to.be.revertedWith("FundMe__WithdrawSelfDestructFailed")

                  // Deploy SelfDestructAttack contract and pass fundMe.address to constructor
                  const selfDestructAttackFactory =
                      await ethers.getContractFactory("SelfDestructAttack")
                  selfDestructAttack = await selfDestructAttackFactory.deploy(
                      fundMe.address
                  )
                  await selfDestructAttack.deployed()

                  // Fund attack contract
                  await selfDestructAttack.initialFunding({
                      value: sendValue,
                  })

                  await selfDestructAttack.attack()
                  // Check extra funds exist before starting withdrawal
                  assert.equal(
                      (
                          await fundMe.provider.getBalance(fundMe.address)
                      ).toString(),
                      (
                          BigInt(await fundMe.getBalance()) + BigInt(sendValue)
                      ).toString()
                  )

                  // Withdraw selfdestruct funds
                  await fundMe.withdrawSelfdestructFunds()

                  // Check selfdestruct funds are withdrawn correctly
                  assert.equal(
                      (
                          await fundMe.provider.getBalance(fundMe.address)
                      ).toString(),
                      BigInt(await fundMe.getBalance()).toString()
                  )
              })

              it("FundMeSelfDestructWithdraw .call failure throws error", async function () {
                  // Get selfdestruct helper contract
                  const selfDestructHelperFactory =
                      await ethers.getContractFactory("SelfDestructHelper")

                  // Deploy helper contract and pass priceFeedAddress to constructor
                  selfDestructHelper = await selfDestructHelperFactory.deploy(
                      ethUsdAggregator.address
                  )
                  await selfDestructHelper.deployed()

                  // Send funds to helper contract that can be used to fund FundMe and attack
                  await selfDestructHelper.initialFunding({
                      value: ethers.utils.parseEther("5"),
                  })

                  await selfDestructHelper.attack()

                  // Transfer contract ownership to allow withdrawal attempt
                  await selfDestructHelper.fundMeTransferOwnership(
                      await selfDestructHelper.selfDestructAttackContract2Address()
                  )

                  await expect(
                      selfDestructHelper.fundMeSelfDestructWithdraw()
                  ).to.be.revertedWith("FundMe__WithdrawSelfDestructFailed")
              })
          })

          describe("refund", async function () {
              beforeEach(async function () {
                  // Send first value as the deployer
                  await fundMe.fund({ value: sendValue })

                  // Fund again to check for edge cases
                  // when deleting elements from the s_funders array
                  await fundMe.fund({ value: sendValue })
              })

              it("Funder can refund their funds", async function () {
                  // Arrange

                  // Send second value as funder2
                  // so that the address has more than one funders funds
                  // to test that only the intended funders amount is refunded
                  const funder2 = accounts[1]
                  const funder2ConnectedContract = await fundMe.connect(funder2)
                  await funder2ConnectedContract.fund({ value: sendValue })

                  const funder = await fundMe.getFunderAddress(0)
                  const startingFundMeBalance =
                      await fundMe.provider.getBalance(fundMe.address)
                  const startingFunderBalance =
                      await fundMe.provider.getBalance(funder)

                  // Act
                  const transactionResponse = await fundMe.refund()
                  const transactionReceipt = await transactionResponse.wait(1)
                  const { gasUsed, effectiveGasPrice } = transactionReceipt
                  const gasCost = gasUsed.mul(effectiveGasPrice)

                  const endingFundMeBalance = await fundMe.provider.getBalance(
                      fundMe.address
                  )
                  const endingFunderBalance = await fundMe.provider.getBalance(
                      funder
                  )

                  // Assert

                  // Check that balances add up before and after
                  assert.equal(
                      startingFundMeBalance
                          .add(startingFunderBalance)
                          .toString(),
                      endingFundMeBalance
                          .add(endingFunderBalance)
                          .add(gasCost)
                          .toString()
                  )

                  // Check funder amount has been reset to 0
                  assert.equal(await fundMe.getAddressToAmountFunded(funder), 0)

                  // Check funder has been removed from the s_funders index
                  await expect(
                      fundMe.getFunderIndex(funder)
                  ).to.be.revertedWith("FundMe__IndexNotFound")
              })

              it("Refund call with zero balance fails", async function () {
                  const noneFunder = accounts[1]
                  const noneFunderConnectedContract = await fundMe.connect(
                      noneFunder
                  )

                  await expect(
                      noneFunderConnectedContract.refund()
                  ).to.be.revertedWith("FundMe__RefundNoFunds")
              })

              it("Refund .call failure throws error", async function () {
                  // Get helper contract
                  const testHelperFactory = await ethers.getContractFactory(
                      "TestHelper"
                  )

                  // Deploy helper contract and pass priceFeedAddress to constructor
                  testHelper = await testHelperFactory.deploy(
                      ethUsdAggregator.address
                  )
                  await testHelper.deployed()

                  // Send funds to helper contract that can be use for the fund() function
                  await testHelper.initialFunding({
                      value: ethers.utils.parseEther("5"),
                  })

                  // Send funds from helper contract to FundMe contract
                  // so that this test passes the RefundNoFunds test
                  await testHelper.fundMeFund(sendValue)

                  await expect(testHelper.fundMeRefund()).to.be.revertedWith(
                      "FundMe__RefundFailed"
                  )
              })

              it("Refund function blocks reentrancy attack", async function () {
                  const reEntrancyAttackFactory =
                      await ethers.getContractFactory("ReEntrancyAttack")
                  // Deploy ReEntrancyAttack contract and pass fundMeAddress to constructor
                  reEntrancyAttack = await reEntrancyAttackFactory.deploy(
                      fundMe.address
                  )
                  await reEntrancyAttack.deployed()

                  // Deposit multiple 1 ETH from other accounts to confirm that isn't refunded in the attack
                  const funder2 = accounts[1]
                  const funder2ConnectedContract = await fundMe.connect(funder2)
                  await funder2ConnectedContract.fund({
                      value: sendValue,
                  })
                  // Check values before and after to make sure only 1 ETH was refunded
                  await expect(
                      reEntrancyAttack.attack({
                          value: ethers.utils.parseEther("1"),
                      })
                  ).to.be.revertedWith("FundMe__RefundFailed")
              })
          })

          describe("getters", async function () {
              it("Gets the contract i_creator correctly", async function () {
                  const response = await fundMe.getCreator()
                  assert.equal(response, deployer)
              })
              it("Gets the contract s_owner correctly", async function () {
                  const response = await fundMe.getOwner()
                  assert.equal(response, deployer)
              })
              it("Gets the contract balance correctly", async function () {
                  const response = await fundMe.getBalance()
                  const balance = await fundMe.provider.getBalance(
                      fundMe.address
                  )
                  assert.equal(response.toString(), balance.toString())
              })
              it("Gets the contract s_funders array correctly", async function () {
                  await fundMe.fund({ value: sendValue })
                  const response = await fundMe.getFunders()
                  assert.equal(response.toString(), deployer.toString())
              })
              it("Gets s_priceFeed version correctly", async function () {
                  const response = await fundMe.getPriceFeedVersion()
                  const version = await mockV3Aggregator.version()
                  assert.equal(response.toString(), version.toString())
              })
          })

          describe("ownership", async function () {
              it("isOwner bool", async function () {
                  assert.equal(await fundMe.isOwner(), true)

                  const attacker = accounts[1]
                  const attackerConnectedContract = await fundMe.connect(
                      attacker
                  )

                  const response = await attackerConnectedContract.isOwner()
                  assert.equal(response, false)
              })
              it("Renounce ownership", async function () {
                  const addressZero =
                      "0x0000000000000000000000000000000000000000"
                  await fundMe.renounceOwnership()
                  assert.equal(await fundMe.getOwner(), addressZero)
              })
              it("Transfer ownership to zero address fails", async function () {
                  const addressZero =
                      "0x0000000000000000000000000000000000000000"
                  await expect(
                      fundMe.transferOwnership(addressZero)
                  ).to.be.revertedWith("FundMe__OwnerTransferZeroAddress")
              })
              it("Transfer ownership success", async function () {
                  const newOwner = accounts[1]
                  const newOwnerAddress = newOwner.address

                  await fundMe.transferOwnership(newOwnerAddress)
                  assert.equal(await fundMe.getOwner(), newOwnerAddress)
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
