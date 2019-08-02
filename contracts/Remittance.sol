pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    uint constant public EXPIRE_LIMIT = 7 days;

    struct BalanceStruct {
        address from;
        uint commission;
        uint value;
        uint expire;
        bool used;
    }
    mapping (bytes32 => BalanceStruct) public balances;

    uint private _commission;
    uint private _commissionTotal;
    uint private _balanceTotal;

    constructor() public {
        _balanceTotal = 0;
        _commission = 1000;
        _commissionTotal = 0;
    }

    event LogDeposited(address indexed sender, uint commission, uint depositedValue);
    event LogRedeemed(address indexed redeemer, uint commission, uint redeemedValue);
    event LogRefunded(address indexed recipient, uint value);
    event LogKilled(address indexed owner);
    event LogNotifiedBeforeSelfdesctruct(string indexed message);

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
        require(msg.value > _commission, "Balance must be bigger than commission");
        require(!balances[hash].used, "Hash shdould not be used before");
        require(hash != bytes32(0), "Hash must be valid");

        // Pre-deduction for commission because changed commission will be a problem on redeem()
        uint finalValue = msg.value.sub(_commission);
        _balanceTotal = _balanceTotal.add(finalValue);
        _commissionTotal = _commissionTotal.add(_commission);
        balances[hash] = BalanceStruct({
            from: msg.sender,
            commission: _commission,
            value: finalValue,
            // TODO: security/no-block-members: Avoid using 'block.timestamp'.
            expire: block.timestamp.add(expire),
            used: true
        });

        emit LogDeposited(msg.sender, _commission, finalValue);

        return true;
    }

    function redeem(bytes32 secretRecipient) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(secretRecipient, msg.sender);
        uint value = balances[hash].value;
        uint commission = balances[hash].commission;
        uint expire = balances[hash].expire;
        require(expire > block.timestamp, "Balance must not be expired");

        _balanceTotal = _balanceTotal.sub(value);
        balances[hash].value = 0;
        // send ether to exchange shop's owner
        msg.sender.transfer(value);

        emit LogRedeemed(msg.sender, commission, value);

        return true;
    }

    // Does not take commission for refund as a good service for users. :)
    function refund(bytes32 hash) public whenNotPaused returns (bool) {
        require(balances[hash].from == msg.sender, "From address must be equal to msg.sender");
        require(balances[hash].expire <= block.timestamp, "Balance must be expired");

        uint value = balances[hash].value;
        require(value > 0, "No balance to be refunded");

        balances[hash].value = 0;
        msg.sender.transfer(value);

        emit LogRefunded(msg.sender, value);

        return true;
    }

    function getBalanceTotal() public view onlyOwner returns (uint) {
        return _balanceTotal;
    }

    function getCommissionTotal() public view onlyOwner returns (uint) {
        return _commissionTotal;
    }

    function getCommission() public view onlyOwner whenNotPaused returns (uint) {
        return _commission;
    }

    function setCommission(uint newCommission) public onlyOwner whenNotPaused returns (bool) {
        _commission = newCommission;

        return true;
    }

    function kill() public onlyOwner returns (bool) {
        if (_balanceTotal > 0) {
            emit LogNotifiedBeforeSelfdesctruct("This contract will be destructed. Please withdraw all balances ASAP.");
            return false;
        }

        emit LogKilled(msg.sender);

        selfdestruct(msg.sender);

        return true;
    }
}
