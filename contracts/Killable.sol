pragma solidity 0.5.10;

import './Pausable.sol';

contract Killable is Pausable {
    bool private _killed;

    event LogKilled(address killedBy);

    modifier whenNotKilled() {
        require(!_killed, "Should not be killed");

        _;
    }

    function kill() public onlyOwner whenPaused whenNotKilled {
        _killed = true;

        emit LogKilled(msg.sender);
    }
}
