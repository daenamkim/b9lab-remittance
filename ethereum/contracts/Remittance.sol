pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    // TODO: make this changeable
    uint constant public commission = 1000;
    uint constant public EXPIRE_LIMIT = 7 days;

    struct BalanceStruct {
        address from;
        uint value;
        uint expire;
    }
    mapping (bytes32 => BalanceStruct) public balances;

    event LogDeposited(address indexed sender, uint indexed originalValue, uint indexed depositedValue);
    event LogRedeemed(address indexed redeemer, uint indexed originalValue, uint indexed redeemedValue);
    event LogRefunded(address indexed recipient, uint indexed value);

    function generateHash(
        bytes32 secretRecipient,
        address exchangeShopOwner
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(secretRecipient, exchangeShopOwner, address(this)));
    }

    function createRemittance(
        bytes32 hash,
        uint expire
    ) public payable whenNotPaused returns (bool) {
        require(expire < EXPIRE_LIMIT, "Expire should be within 7 days");
        require(msg.value > 0, "Value must be bigger than 0");
        require(hash != bytes32(0), "Hash must be valid");
        require(balances[hash].value == 0, "Balance should be 0 for this hash");

        balances[hash] = BalanceStruct({
            from: msg.sender,
            value: msg.value,
            // TODO: security/no-block-members: Avoid using 'block.timestamp'.
            expire: block.timestamp.add(expire)
        });

        emit LogDeposited(msg.sender, msg.value, msg.value.sub(commission));

        return true;
    }

    function redeem(bytes32 secretRecipient) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(secretRecipient, msg.sender);
        require(balances[hash].expire > block.timestamp, "Balance must not be expired");

        uint value = balances[hash].value;
        require(value > commission, "Balance must be bigger than commission");

        // send ether to exchange shop's owner
        balances[hash].value = 0;
        msg.sender.transfer(value);

        emit LogRedeemed(msg.sender, value, value.sub(commission));

        return true;
    }

    // Does not take commission for refund as a good service for users. :)
    function refund(bytes32 secretRecipient) public whenNotPaused returns (bool) {
        bytes32 hash = generateHash(secretRecipient, msg.sender);
        require(balances[hash].from == msg.sender, "From address must be equal to msg.sender");
        require(balances[hash].expire <= block.timestamp, "Balance must be expired");

        uint value = balances[hash].value;
        require(value > 0, "No balance to be refunded");

        balances[hash].value = 0;
        msg.sender.transfer(value);

        emit LogRefunded(msg.sender, value);

        return true;
    }

    // TODO: add a function take commission back later

    function kill() public onlyOwner {
      selfdestruct(msg.sender);
    }
}
