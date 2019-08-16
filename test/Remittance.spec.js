const truffleAssert = require('truffle-assertions');
const artifactRemittance = artifacts.require('Remittance.sol');
const { toBN, toWei } = web3.utils;

contract('Remittance', accounts => {
  const [alice, bob, carol, ownerCandidate] = accounts;

  let remittanceInstance;
  beforeEach('deploy a new Remittance contract', async () => {
    remittanceInstance = await artifactRemittance.new({ from: alice });
  });

  it('should return a hash', async () => {
    const expected =
      '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f';
    const actual = await remittanceInstance.generateHash(
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      carol
    );
    assert.strictEqual(actual, expected);
  });

  it('should return current commission', async () => {
    const expected = 1000;
    const actual = await remittanceInstance.getCommission();
    assert.strictEqual(actual.toString(), toBN(expected).toString());
  });

  it('should avoid a user not owner candidate to accept a new owner', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await truffleAssert.fails(
      remittanceInstance.acceptOwnerCandidate({
        from: bob
      }),
      'Sender should be owner candidate'
    );
  });

  it('should avoid to request for new candidate multiple times', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await truffleAssert.fails(
      remittanceInstance.requestOwnerCandidate(ownerCandidate, {
        from: alice
      }),
      'Owner candidate should not be set previously'
    );
  });

  it('should avoid to accept new owner request multiple times', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await remittanceInstance.acceptOwnerCandidate({
      from: ownerCandidate
    });
    await truffleAssert.fails(
      remittanceInstance.acceptOwnerCandidate({
        from: ownerCandidate
      }),
      'Sender should be owner candidate'
    );
  });

  it('should avoid a owner withdraw commissions collected when the owner candidate is requested', async () => {
    await remittanceInstance.createRemittance(
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      '1000',
      {
        from: alice,
        value: '1001'
      }
    );
    await remittanceInstance.withdrawCommissionCollected({
      from: alice
    });
    const commissionCollected = await remittanceInstance.getCommissionCollected();
    assert.isTrue(commissionCollected.eqn(0));

    await remittanceInstance.createRemittance(
      '0x0000000000000000000000000000000000000000000000000000000000000002',
      '1000',
      {
        from: alice,
        value: '1001'
      }
    );
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await truffleAssert.fails(
      remittanceInstance.withdrawCommissionCollected({
        from: alice
      }),
      'Only owner candidate was not requested'
    );
  });

  it('should change owner', async () => {
    let ownerCurrent = await remittanceInstance.getOwner();
    let ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');

    const resultRequest = await remittanceInstance.requestOwnerCandidate(
      ownerCandidate,
      {
        from: alice
      }
    );
    assert.strictEqual(
      resultRequest.logs[0].event,
      'LogOwnerCandidateRequested'
    );
    assert.strictEqual(resultRequest.logs[0].args.owner, alice);
    assert.strictEqual(resultRequest.logs[0].args.candidate, ownerCandidate);

    ownerCurrent = await remittanceInstance.getOwner();
    ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerNew, ownerCandidate);

    const resultAccept = await remittanceInstance.acceptOwnerCandidate({
      from: ownerCandidate
    });
    assert.strictEqual(resultAccept.logs[0].event, 'LogOwnerCandidateAccepted');
    assert.strictEqual(resultAccept.logs[0].args.ownerNew, ownerCandidate);

    ownerCurrent = await remittanceInstance.getOwner();
    ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, ownerCandidate);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');
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

  it('should avoid all users not owner to access to collected commissions', async () => {
    await truffleAssert.fails(
      remittanceInstance.getCommissionCollected({
        from: bob
      }),
      'Should be only owner'
    );
    await truffleAssert.fails(
      remittanceInstance.withdrawCommissionCollected({
        from: bob
      }),
      'Should be only owner'
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
