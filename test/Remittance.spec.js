const truffleAssert = require('truffle-assertions');
const artifactRemittance = artifacts.require('Remittance.sol');

contract('Remittance', accounts => {
  const [alice, bob, carol, ownerCandidate] = accounts;
  const gas = '110000'; // gas limit

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
    assert.isTrue(actual.eqn(expected));
  });
  it('should avoid a user not owner candidate to accept a new owner', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.acceptOwnerCandidate({
        from: bob,
        gas
      }),
      'Sender should be owner candidate'
    );
  });
  it('should avoid to request for new candidate multiple times', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.requestOwnerCandidate(ownerCandidate, {
        from: alice,
        gas
      }),
      'Owner candidate should not be set previously'
    );
  });
  it('should avoid to accept new owner request multiple times', async () => {
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice,
      gas
    });
    await remittanceInstance.acceptOwnerCandidate({
      from: ownerCandidate,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.acceptOwnerCandidate({
        from: ownerCandidate,
        gas
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
        gas,
        value: '1001'
      }
    );
    await remittanceInstance.withdrawCommissionCollected({
      from: alice,
      gas
    });
    const commissionCollected = await remittanceInstance.getCommissionCollected();
    assert.isTrue(commissionCollected.eqn(0));

    await remittanceInstance.createRemittance(
      '0x0000000000000000000000000000000000000000000000000000000000000002',
      '1000',
      {
        from: alice,
        gas,
        value: '1001'
      }
    );
    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.withdrawCommissionCollected({
        from: alice,
        gas
      }),
      'Only owner candidate was not requested'
    );
  });
  it('should change owner', async () => {
    let ownerCurrent = await remittanceInstance.getOwner();
    let ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');

    await remittanceInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice,
      gas
    });
    ownerCurrent = await remittanceInstance.getOwner();
    ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerCandidate, ownerNew);

    await remittanceInstance.acceptOwnerCandidate({
      from: ownerCandidate,
      gas
    });
    ownerCurrent = await remittanceInstance.getOwner();
    ownerNew = await remittanceInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, ownerCandidate);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');
  });
  it('should avoid all users to writing to storage when it is paused', async () => {
    remittanceInstance.pause({
      from: alice,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.createRemittance(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        '1000',
        {
          from: alice,
          gas,
          value: '1001'
        }
      ),
      'Should not be paused'
    );
    await truffleAssert.fails(
      remittanceInstance.redeem(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        {
          from: carol,
          gas
        }
      ),
      'Should not be paused'
    );
    await truffleAssert.fails(
      remittanceInstance.refund(
        '0x0000000000000000000000000000000000000000000000000000000000000003',
        {
          from: alice,
          gas
        }
      ),
      'Should not be paused'
    );
  });
  it.only('should avoid all users and owner to write to storage when it is killed', async () => {
    remittanceInstance.kill({
      from: alice,
      gas
    });
    await truffleAssert.fails(
      remittanceInstance.createRemittance(
        '0x87b179583f559e625fb9cf098c1a6210384660fa34a282f7649b43ed25f1fe2f',
        '1000',
        {
          from: alice,
          gas,
          value: '1001'
        }
      ),
      'Should not be killed'
    );
    await truffleAssert.fails(
      remittanceInstance.redeem(
        '0x0000000000000000000000000000000000000000000000000000000000000001',
        {
          from: carol,
          gas
        }
      ),
      'Should not be killed'
    );
    await truffleAssert.fails(
      remittanceInstance.setCommission('1500', {
        from: alice,
        gas
      }),
      'Should not be killed'
    );
  });
  it.skip('should avoid all users not owner to access to collected commissions', async () => {
    // getCommissionCollected
    // withdrawCommissionCollected
  });
  it.skip('should deposit money and redeem from exchange shop owner successfully', async () => {
    // remittance
    // redeem
  });
});
