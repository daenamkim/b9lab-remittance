pragma solidity 0.5.10;

import "./Killable.sol";
import "./SafeMath.sol";

contract Remittance is Killable {
    using SafeMath for uint256;

    uint constant public EXPIRE_LIMIT = 7 days;

    struct BalanceStruct {
        address from;
        uint commission;
        uint value;
        uint expire;
    }
    mapping (bytes32 => BalanceStruct) public balances;

    uint private _commission;
    uint private _commissionCollected;

    constructor() public {
        _commission = 1000;
    }

    event LogDeposited(address indexed sender, uint commission, uint depositedValue);
    event LogRedeemed(address indexed redeemer, uint commission, uint redeemedValue);
    event LogRefunded(address indexed recipient, uint value);
    event LogSetCommission(address indexed owner, uint newCommission);
    event LogWithdrawedCommissionCollected(address indexed owner, uint commissionCollected);

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
        require(expire < EXPIRE_LIMIT, "Expire should be within 7 days");
        require(msg.value > _commission, "Balance must be bigger than commission");
        require(hash != bytes32(0), "Hash must be valid");
        require(balances[hash].value == 0, "Balance should be 0 for this hash");

        // Pre-deduction for commission because changed commission will be a problem on redeem()
        uint finalValue = msg.value.sub(_commission);
        _commissionCollected = _commissionCollected.add(_commission);
        balances[hash] = BalanceStruct({
            from: msg.sender,
            commission: _commission,
            value: finalValue,
            // TODO: security/no-block-members: Avoid using 'block.timestamp'.
            expire: block.timestamp.add(expire)
        });

        emit LogDeposited(msg.sender, _commission, finalValue);

        return true;
    }

    function redeem(bytes32 secretRecipient) external whenNotPaused whenNotKilled returns (bool) {
        bytes32 hash = generateHash(secretRecipient, msg.sender);
        uint value = balances[hash].value;
        uint commission = balances[hash].commission;
        uint expire = balances[hash].expire;
        require(expire > block.timestamp, "Balance must not be expired");

        balances[hash].value = 0;

        emit LogRedeemed(msg.sender, commission, value);

        // send ether to exchange shop's owner
        msg.sender.transfer(value);

        return true;
    }

    // Does not take commission for refund as a good service for users. :)
    function refund(bytes32 hash) public whenNotPaused returns (bool) {
        require(balances[hash].from == msg.sender, "From address must be equal to msg.sender");

        uint value = balances[hash].value;
        require(value > 0, "No balance to be refunded");

        balances[hash].value = 0;
        msg.sender.transfer(value);

        emit LogRefunded(msg.sender, value);

        return true;
    }

    function getCommissionCollected() public view onlyOwner returns (uint) {
        return _commissionCollected;
    }

    function withdrawCommissionCollected() public onlyOwner returns (bool) {
        uint value = _commissionCollected;
        require(value > 0, "Commission must be bigger than 0");

        _commissionCollected = 0;
        msg.sender.transfer(value);

        emit LogWithdrawedCommissionCollected(msg.sender, value);

        return true;
    }

    function getCommission() public view onlyOwner whenNotPaused returns (uint) {
        return _commission;
    }

    function setCommission(uint newCommission) public onlyOwner whenNotPaused whenNotKilled returns (bool) {
        _commission = newCommission;

        emit LogSetCommission(msg.sender, newCommission);

        return true;
    }
}
