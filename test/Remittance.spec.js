const truffleAssert = require('truffle-assertions');
const artifactRemittance = artifacts.require('Remittance.sol');

contract('Remittance', accounts => {
  const [alice, bob, carol] = accounts;

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
  it.only('should return current commission', async () => {
    const expected = 1000;
    const actual = await remittanceInstance.getCommission();
    assert.isTrue(actual.eqn(expected));
  });
  it('should change owner', async () => {});
  it('should avoid all users to writing to storage when it is paused', async () => {
    // createRemittance
    // redeem
    // refund
  });
  it('should avoid all users and owner to write to storage when it is killed', async () => {
    // createRemittance
    // redeem
    // setCommission
  });
  it('should avoid all users not owner to access to collected commissions', async () => {
    // getCommissionCollected
    // withdrawCommissionCollected
  });
  it('should avoid a owner withdraw commissions collected when the owner candidate is requested', async () => {
    // withdrawCommissionCollected
  });
});
