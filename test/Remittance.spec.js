const truffleAssert = require('truffle-assertions');
const Remittance = artifacts.require('Remittance.sol');
const { toBN, toWei } = web3.utils;

contract('Remittance', accounts => {
  const [alice, bob, carol, ownerCandidate] = accounts;

  let remittanceInstance;
  beforeEach('deploy a new Remittance contract', async () => {
    remittanceInstance = await Remittance.new({ from: alice });
  });

  it('should return current commission', async () => {
    const actual = await remittanceInstance.getCommission();
    assert.strictEqual(actual.toString(), '1000');
  });

  it('should avoid reusing same hash again', async () => {
    await remittanceInstance.createRemittance(
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      '1000',
      {
        from: alice,
        value: '1001'
      }
    );

    await truffleAssert.fails(
      remittanceInstance.createRemittance(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        '1000',
        {
          from: alice,
          value: '1001'
        }
      ),
      'Hash must not have been used before'
    );
  });

  it('should avoid all users to writing to storage when it is paused', async () => {
    remittanceInstance.pause({
      from: alice
    });
    await truffleAssert.fails(
      remittanceInstance.createRemittance(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        '1000',
        {
          from: alice,
          value: '1001'
        }
      ),
      'Should not be paused'
    );
    await truffleAssert.fails(
      remittanceInstance.redeem(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        {
          from: carol
        }
      ),
      'Should not be paused'
    );
    await truffleAssert.fails(
      remittanceInstance.refund(
        '0x0000000000000000000000000000000000000000000000000000000000000003',
        {
          from: alice
        }
      ),
      'Should not be paused'
    );
  });

  it('should avoid all users and owner to write to storage when it is killed', async () => {
    remittanceInstance.kill({
      from: alice
    });
    await truffleAssert.fails(
      remittanceInstance.createRemittance(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        '1000',
        {
          from: alice,
          value: '1001'
        }
      ),
      'Should not be killed'
    );
    await truffleAssert.fails(
      remittanceInstance.redeem(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        {
          from: carol
        }
      ),
      'Should not be killed'
    );
    await truffleAssert.fails(
      remittanceInstance.setCommission('1500', {
        from: alice
      }),
      'Should not be killed'
    );
  });

  it('should redeem from exchange shop owner successfully', async () => {
    const hash = await remittanceInstance.generateHash(
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      carol
    );
    const commission = await remittanceInstance.getCommission();
    const resultDeposit = await remittanceInstance.createRemittance(
      hash,
      '1000',
      {
        from: alice,
        value: toWei('1', 'ether')
      }
    );
    assert.strictEqual(resultDeposit.logs[0].event, 'LogDeposited');
    assert.strictEqual(resultDeposit.logs[0].args.sender, alice);
    assert.strictEqual(
      resultDeposit.logs[0].args.commission.toString(),
      '1000'
    );

    assert.strictEqual(
      resultDeposit.logs[0].args.depositedValue.toString(),
      toBN(toWei('1', 'ether'))
        .sub(commission)
        .toString()
    );

    const balanceCarolBefore = await web3.eth.getBalance(carol);
    const resultRedeem = await remittanceInstance.redeem(
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      { from: carol }
    );
    assert.strictEqual(resultRedeem.logs[0].event, 'LogRedeemed');
    assert.strictEqual(resultRedeem.logs[0].args.redeemer, carol);
    assert.strictEqual(
      resultRedeem.logs[0].args.redeemedValue.toString(),
      toBN(toWei('1', 'ether'))
        .sub(commission)
        .toString()
    );

    const balanceCarolAfter = await web3.eth.getBalance(carol);
    assert.isTrue(toBN(balanceCarolAfter).gt(balanceCarolBefore));

    await truffleAssert.fails(
      remittanceInstance.redeem(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        { from: carol }
      ),
      'No balance to redeem'
    );
  });

  it('should withdraw commission collected successfully', async () => {
    await remittanceInstance.createRemittance(
      '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
      '1000',
      {
        from: alice,
        value: toWei('1', 'ether')
      }
    );

    const balanceAliceBefore = await web3.eth.getBalance(alice);
    const resultWithdraw = await remittanceInstance.withdrawCommissionCollected(
      {
        from: alice
      }
    );
    assert.strictEqual(
      resultWithdraw.logs[0].event,
      'LogCommissionCollectedWithdrew'
    );
    assert.strictEqual(resultWithdraw.logs[0].args.owner, alice);
    assert.strictEqual(
      resultWithdraw.logs[0].args.commissionCollected.toString(),
      '1000'
    );

    const balanceAliceAfter = await web3.eth.getBalance(alice);
    assert.isTrue(toBN(balanceAliceAfter).gt(balanceAliceBefore));

    await truffleAssert.fails(
      remittanceInstance.withdrawCommissionCollected({
        from: alice
      }),
      'No commission collected to withdraw'
    );
  });

  it('should set commission successfully', async () => {
    const commissionCurrent = await remittanceInstance.getCommission();
    assert.strictEqual(commissionCurrent.toString(), '1000');

    const result = await remittanceInstance.setCommission('1500', {
      from: alice
    });
    const commissionNew = await remittanceInstance.getCommission();
    assert.strictEqual(commissionNew.toString(), '1500');
    assert.strictEqual(result.logs[0].event, 'LogCommissionSet');
    assert.strictEqual(result.logs[0].args.owner, alice);
    assert.strictEqual(
      result.logs[0].args.newCommission.toString(),
      commissionNew.toString()
    );
  });

  it('should avoid users to refund before expire', async () => {
    await remittanceInstance.createRemittance(
      '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
      '1000',
      {
        from: alice,
        value: toWei('1', 'ether')
      }
    );

    await truffleAssert.fails(
      remittanceInstance.refund(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        {
          from: alice
        }
      ),
      "Can't refund until expired"
    );
  });

  it('should refund deposited successfully', async () => {
    const commission = await remittanceInstance.getCommission();
    await remittanceInstance.createRemittance(
      '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
      '0',
      {
        from: alice,
        value: toWei('1', 'ether')
      }
    );

    await new Promise(resolve => {
      setTimeout(() => {
        resolve();
      }, 1000);
    });

    const balanceAliceBefore = await web3.eth.getBalance(alice);
    const resultRefund = await remittanceInstance.refund(
      '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
      {
        from: alice
      }
    );
    assert.strictEqual(resultRefund.logs[0].event, 'LogRefunded');
    assert.strictEqual(resultRefund.logs[0].args.recipient, alice);
    assert.strictEqual(
      resultRefund.logs[0].args.value.toString(),
      toBN(toWei('1', 'ether'))
        .sub(commission)
        .toString()
    );

    const balanceAliceAfter = await web3.eth.getBalance(alice);
    assert.isTrue(toBN(balanceAliceAfter).gt(balanceAliceBefore));

    await truffleAssert.fails(
      remittanceInstance.refund(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        {
          from: alice
        }
      ),
      'No balance to be refunded'
    );
  });
});
