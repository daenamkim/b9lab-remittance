pragma solidity 0.5.10;

import './Pausable.sol';

contract Remittance {
    function remit(string memory password1, string memory password2) public;
    function withdrawed(address receiver) external;
}

contract ExchangeShop is Pausable {
    mapping(address => uint) balances;
    mapping(bytes32 => address) senders;

    function exchange(
        Remittance remittanceContract,
        string memory password1,
        string memory password2,
        address receiver
    ) public onlyOwner whenNotPaused {
        bytes32 key = keccak256(abi.encodePacked(this, receiver, password1));
        senders[key] = address(remittanceContract);

        // Request Alice to take value with two-pair passwords
        (bool ok,) = address(remittanceContract).call(
            abi.encodeWithSignature('remit(string,string,address)', password1, password2, receiver)
        );
        require(ok, 'Remit should be called');
    }

    function updateBalance(address receiver, uint value) external whenNotPaused {
        require(receiver != address(0), 'Receiver should have an address');
        require(value > 0, 'Value should be greater than 0');

        balances[receiver] = value;
    }

    function withdraw(string memory password) public whenNotPaused {
        bytes32 key = keccak256(abi.encodePacked(this, msg.sender, password));
        require(senders[key] != address(0), 'Receiver with password should be mapped to original sender');
        require(balances[msg.sender] > 0, 'Should have some balance');

        msg.sender.transfer(balances[msg.sender]);
        balances[msg.sender] = 0;

        // Notify to Alice
        (bool ok,) = address(senders[key]).call(
          abi.encodeWithSignature('withdrawed(address)', msg.sender)
        );
        require(ok, 'withdrawed should be called');
    }
}
