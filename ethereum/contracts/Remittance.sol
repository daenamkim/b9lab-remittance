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
    mapping (address => mapping (bytes32 => bool)) public notifications;

    event LogRemit(address indexed sender, uint indexed finalValue, uint indexed commission);
    event LogWithdrawed(address indexed recipient);
    event LogClaimBack(address indexed recipient, uint indexed value);

    function generateHash(
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(recipient, secretRecipient, secretExchangeShop));
    }

    function checkHash(
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop,
        bytes32 hash
    ) public pure returns (bool) {
        if (generateHash(recipient, secretRecipient, secretExchangeShop) == hash) {
            return true;
        }

        return false;
    }

    function deposit(
        address recipient,
        bytes32 hash,
        uint expire
    ) public payable onlyOwner whenNotPaused returns (bool) {
        require(msg.value > 0, "Value must be bigger than 0");
        require(hash != bytes32(0), "Hash must be valid");
        require(recipient != address(0), "Address must be valid");

        balances[hash].value = msg.value;
        // TODO: security/no-block-members: Avoid using 'block.timestamp'.
        balances[hash].expire = block.timestamp.add(expire);

        return true;
    }

    function remit(
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(recipient, secretRecipient, secretExchangeShop);
        require(recipient != address(0), "Address must be valid");
        require(checkHash(recipient, secretRecipient, secretExchangeShop, hash), "Secrets must be valid");
        require(balances[hash].expire > block.timestamp, "Balance must not be expired");
        uint value = balances[hash].value;
        require(value > commission, "Balance must be enough to pay commission");
        uint finalValue = value.sub(commission);

        balances[hash].value = 0;
        // TODO: set gas?
        // TODO: security/no-call-value: Consider using 'transfer' in place of 'call.value()'.
        (bool ok,) = msg.sender.call.value(finalValue)(abi.encodeWithSignature("deposit(address)", recipient));
        require(ok, "Deposit to Exchange Shop must be successful");

        // send commision back to the owner of a contract
        address payable owner = getOwner();
        owner.transfer(commission);

        emit LogRemit(msg.sender, finalValue, commission);
        notifications[recipient][generateHash(recipient, secretRecipient, "")] = true;

        return true;
    }

    function withdrawedFromExchangeShop(address recipient, bytes32 secretRecipient) external returns (bool) {
        bytes32 hash = generateHash(recipient, secretRecipient, "");
        require(notifications[recipient][hash], "Notfication doesn't exist");

        notifications[recipient][hash] = false;
        emit LogWithdrawed(recipient);

        return true;
    }

    function claimBack(
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop
    ) public onlyOwner whenNotPaused returns (bool) {
        bytes32 hash = generateHash(recipient, secretRecipient, secretExchangeShop);
        require(checkHash(recipient, secretRecipient, secretExchangeShop, hash), "Hass must be valid");
        require(balances[hash].expire <= block.timestamp, "Balance must be expired");

        uint value = balances[hash].value;
        balances[hash].value = 0;
        notifications[recipient][hash] = false;
        msg.sender.transfer(value);
        emit LogClaimBack(recipient, value);

        return true;
    }

    function kill() public onlyOwner {
      selfdestruct(msg.sender);
    }

    function updateSerets(
        address recipient,
        bytes32 secretRecipient,
        bytes32 secretExchangeShop,
        bytes32 secretRecipientNew,
        bytes32 secretExchangeShopNew
    ) public onlyOwner returns (bool) {
        bytes32 hash = generateHash(recipient, secretRecipient, secretExchangeShop);
        uint value = balances[hash].value;
        require(value > 0, "Balance must be bigger than 0 if you want to update secrets");

        bytes32 hashNew = generateHash(recipient, secretRecipientNew, secretExchangeShopNew);
        balances[hashNew].value = value;
        balances[hashNew].expire = balances[hash].expire;
        balances[hash].value = 0;

        return true;
    }
}
