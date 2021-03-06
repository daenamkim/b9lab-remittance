pragma solidity 0.5.10;

import "./Killable.sol";
import "./SafeMath.sol";

contract Remittance is Killable {
    using SafeMath for uint256;

    uint constant public EXPIRE_LIMIT = 7 days;

    struct BalanceStruct {
        address from;
        uint value;
        uint expire;
    }
    mapping (bytes32 => BalanceStruct) public balances;

    mapping(address => uint) public commissions;
    uint private _commission;

    constructor() public {
        _commission = 1000;
    }

    event LogDeposited(address indexed sender, uint commission, uint depositedValue);
    event LogRedeemed(address indexed redeemer, uint redeemedValue);
    event LogRefunded(address indexed recipient, uint value);
    event LogCommissionSet(address indexed owner, uint newCommission);
    event LogCommissionCollectedWithdrew(address indexed owner, uint commissionCollected);

    function generateHash(
        bytes32 secretRecipient,
        address exchangeShopOwner
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(secretRecipient, exchangeShopOwner, address(this)));
    }

    function createRemittance(
        bytes32 hash,
        uint expire
    ) public payable whenNotPaused whenNotKilled returns (bool) {
        uint commission = _commission;
        require(expire < EXPIRE_LIMIT, "Expire should be within 7 days");
        require(msg.value > commission, "Balance must be bigger than commission");
        require(hash != bytes32(0), "Hash must be valid");
        require(balances[hash].from == address(0), "Hash must not have been used before");

        address owner = getOwner();
        commissions[owner] = commissions[owner].add(commission);

        // Pre-deduction for commission because changed commission will be a problem on redeem()
        uint finalValue = msg.value.sub(commission);
        balances[hash] = BalanceStruct({
            from: msg.sender,
            value: finalValue,
            // TODO: security/no-block-members: Avoid using 'block.timestamp'.
            expire: block.timestamp.add(expire)
        });

        emit LogDeposited(msg.sender, commission, finalValue);

        return true;
    }

    function redeem(bytes32 secretRecipient) external whenNotPaused whenNotKilled returns (bool) {
        bytes32 hash = generateHash(secretRecipient, msg.sender);
        uint value = balances[hash].value;
        require(value > 0, "No balance to redeem");

        emit LogRedeemed(msg.sender, value);

        // send ether to exchange shop's owner
        balances[hash].value = 0;
        balances[hash].expire = 0;
        msg.sender.transfer(value);

        return true;
    }

    // Does not take commission for refund as a good service for users. :)
    function refund(bytes32 hash) public whenNotPaused returns (bool) {
        require(balances[hash].from == msg.sender, "From address must be equal to msg.sender");
        require(balances[hash].expire <= block.timestamp, "Can't refund until expired");

        uint value = balances[hash].value;
        require(value > 0, "No balance to be refunded");

        emit LogRefunded(msg.sender, value);

        balances[hash].value = 0;
        balances[hash].expire = 0;
        msg.sender.transfer(value);

        return true;
    }

    function withdrawCommissionCollected() public returns (bool) {
        uint value = commissions[msg.sender];
        require(value > 0, "No commission collected to withdraw");

        emit LogCommissionCollectedWithdrew(msg.sender, value);

        commissions[msg.sender] = 0;
        msg.sender.transfer(value);

        return true;
    }

    function getCommission() public view returns (uint) {
        return _commission;
    }

    function setCommission(uint newCommission) public onlyOwner whenNotKilled returns (bool) {
        _commission = newCommission;

        emit LogCommissionSet(msg.sender, newCommission);

        return true;
    }
}
