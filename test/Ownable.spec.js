const truffleAssert = require('truffle-assertions');
const artifactOwnable = artifacts.require('Ownable.sol');

contract('Ownable', accounts => {
  const [alice, bob, ownerCandidate] = accounts;

  let ownableInstance;
  beforeEach('deploy a new Ownable contract', async () => {
    ownableInstance = await artifactOwnable.new({ from: alice });
  });

  it('should avoid a user not owner candidate to accept a new owner', async () => {
    await ownableInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await truffleAssert.fails(
      ownableInstance.acceptOwnerCandidate({
        from: bob
      }),
      'Sender should be owner candidate'
    );
  });

  it('should avoid to request for new candidate multiple times', async () => {
    await ownableInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await truffleAssert.fails(
      ownableInstance.requestOwnerCandidate(ownerCandidate, {
        from: alice
      }),
      'Owner candidate should not be set previously'
    );
  });

  it('should avoid to accept new owner request multiple times', async () => {
    await ownableInstance.requestOwnerCandidate(ownerCandidate, {
      from: alice
    });
    await ownableInstance.acceptOwnerCandidate({
      from: ownerCandidate
    });
    await truffleAssert.fails(
      ownableInstance.acceptOwnerCandidate({
        from: ownerCandidate
      }),
      'Sender should be owner candidate'
    );
  });

  it('should change owner', async () => {
    let ownerCurrent = await ownableInstance.getOwner();
    let ownerNew = await ownableInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');

    const resultRequest = await ownableInstance.requestOwnerCandidate(
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

    ownerCurrent = await ownableInstance.getOwner();
    ownerNew = await ownableInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, alice);
    assert.strictEqual(ownerNew, ownerCandidate);

    const resultAccept = await ownableInstance.acceptOwnerCandidate({
      from: ownerCandidate
    });
    assert.strictEqual(resultAccept.logs[0].event, 'LogOwnerCandidateAccepted');
    assert.strictEqual(resultAccept.logs[0].args.ownerNew, ownerCandidate);

    ownerCurrent = await ownableInstance.getOwner();
    ownerNew = await ownableInstance.getOwnerCandidate();
    assert.strictEqual(ownerCurrent, ownerCandidate);
    assert.strictEqual(ownerNew, '0x0000000000000000000000000000000000000000');
  });
});
