pragma solidity 0.5.10;

import "./Pausable.sol";
import "./SafeMath.sol";

contract Remittance is Pausable {
    using SafeMath for uint256;

    uint constant public commission = 1000;

    struct BalanceStruct {
        uint value;
        uint32 expire;
    }
    mapping (bytes32 => BalanceStruct) public balances;
    mapping (address => mapping (bytes32 => bool)) public notifications;

    event LogRemit(address indexed sender, uint indexed finalValue, uint indexed commission);
    event LogWithdrawed(address indexed to);
    event LogClaimBack(address indexed to, uint indexed value);

    function generateHash(
        address to,
        string memory secretTo,
        string memory secretExchangeShop
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(to, secretTo, secretExchangeShop));
    }

    function checkHash(
        address to,
        string memory secretTo,
        string memory secretExchangeShop,
        bytes32 hash
    ) public pure returns (bool) {
        if (generateHash(to, secretTo, secretExchangeShop) == hash) {
            return true;
        }

        return false;
    }

    function deposit(
        address to,
        bytes32 hash,
        uint32 expire
    ) public payable onlyOwner whenNotPaused returns (bool) {
        require(msg.value > 0, "Value must be bigger than 0");
        require(hash != bytes32(0), "Hash must be valid");
        require(to != address(0), "Address must be valid");

        balances[hash].value = msg.value;
        // TODO: security/no-block-members: Avoid using 'block.timestamp'.
        balances[hash].expire = uint32(block.timestamp) + expire;

        return true;
    }

    function remit(
        address to,
        string calldata secretTo,
        string calldata secretExchangeShop
    ) external whenNotPaused returns (bool) {
        bytes32 hash = generateHash(to, secretTo, secretExchangeShop);
        require(to != address(0), "Address must be valid");
        require(checkHash(to, secretTo, secretExchangeShop, hash), "Secrets must be valid");
        require(balances[hash].expire > uint32(block.timestamp), "Balance must not be expired");
        uint value = balances[hash].value;
        require(value > commission, "Balance must be enough to pay commission");
        uint finalValue = value.sub(commission);

        balances[hash].value = 0;
        // TODO: set gas?
        // TODO: security/no-call-value: Consider using 'transfer' in place of 'call.value()'.
        (bool ok,) = msg.sender.call.value(finalValue)(abi.encodeWithSignature("deposit(address)", to));
        require(ok, "Deposit to Exchange Shop must be successful");

        // send commision back to the owner of a contract
        address payable owner = getOwner();
        owner.transfer(commission);

        emit LogRemit(msg.sender, finalValue, commission);
        notifications[to][generateHash(to, secretTo, "")] = true;

        return true;
    }

    function withdrawedFromExchangeShop(address to, string calldata secretTo) external returns (bool) {
        bytes32 hash = generateHash(to, secretTo, "");
        require(notifications[to][hash], "Notfication doesn't exist");

        notifications[to][hash] = false;
        emit LogWithdrawed(to);

        return true;
    }

    function claimBack(
        address to,
        string memory secretTo,
        string memory secretExchangeShop
    ) public onlyOwner whenNotPaused returns (bool) {
        bytes32 hash = generateHash(to, secretTo, secretExchangeShop);
        require(checkHash(to, secretTo, secretExchangeShop, hash), "Hass must be valid");
        require(balances[hash].expire <= uint32(block.timestamp), "Balance must be expired");

        uint value = balances[hash].value;
        balances[hash].value = 0;
        notifications[to][hash] = false;
        msg.sender.transfer(value);
        emit LogClaimBack(to, value);

        return true;
    }

    function kill() public onlyOwner {
      selfdestruct(msg.sender);
    }

    function updateSerets(
        address to,
        string memory secretTo,
        string memory secretExchangeShop,
        string memory secretToNew,
        string memory secretExchangeShopNew
    ) onlyOwner public returns (bool) {
        bytes32 hash = generateHash(to, secretTo, secretExchangeShop);
        uint value = balances[hash].value;
        require(value > 0, "Balance must be bigger than 0 if you want to update secrets");

        bytes32 hashNew = generateHash(to, secretToNew, secretExchangeShopNew);
        balances[hashNew].value = value;
        balances[hashNew].expire = balances[hash].expire;
        balances[hash].value = 0;

        return true;
    }
}
