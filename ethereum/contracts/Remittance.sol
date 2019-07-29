pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    uint constant public commission = 1000;

    struct BalanceStruct {
        uint value;
        uint expire;
    }
    mapping (bytes32 => BalanceStruct) public balances;

    event LogRedeem(address indexed redeemer, uint indexed finalValue);
    event LogClaimBack(address indexed recipient, uint indexed value);

    function generateHash(
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(secretRecipient, secretExchangeShop, this));
    }

    function createRemittance(
        bytes32 hash,
        uint expire
    ) public payable onlyOwner whenNotPaused returns (bool) {
        require(msg.value > 0, "Value must be bigger than 0");
        require(hash != bytes32(0), "Hash must be valid");
        require(balances[hash].value == 0, "Balance should be 0 for this hash");

        balances[hash].value = msg.value;
        // TODO: security/no-block-members: Avoid using 'block.timestamp'.
        balances[hash].expire = block.timestamp.add(expire);

        return true;
    }

    function redeem(
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(secretRecipient, secretExchangeShop);
        require(balances[hash].value > 0, "Hash must exists or balace must be bigger than 0");
        require(balances[hash].expire > block.timestamp, "Balance must not be expired");

        uint value = balances[hash].value;
        require(value > commission, "Balance must be enough to pay commission");
        uint finalValue = value.sub(commission);
        balances[hash].value = 0;
        // send ether to exchange shop's owner
        msg.sender.transfer(finalValue);
        // send commision back to the owner of a contract because Alice is providing this contract for users
        address(bytes20(getOwner())).transfer(commission);

        emit LogRedeem(msg.sender, finalValue);

        return true;
    }

    function claimBack(bytes32 hash) public whenNotPaused returns (bool) {
        require(balances[hash].expire <= block.timestamp, "Balance must be expired");

        uint value = balances[hash].value;
        balances[hash].value = 0;
        msg.sender.transfer(value);

        emit LogClaimBack(msg.sender, value);

        return true;
    }

    function kill() public onlyOwner {
      selfdestruct(msg.sender);
    }
}
