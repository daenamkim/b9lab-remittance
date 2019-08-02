pragma solidity 0.5.10;

contract Ownable {
    address private _owner;
    address private _ownerCandidate;

    constructor() public {
        _owner = msg.sender;
    }

    event LogRequestOwnerCandidate(address indexed owner, address candidate);
    event LogAcceptOwnerCandidate(address indexed owner, address candidate);
    event LogRevokeOwnerCandidate(address indexed owner, address candidate);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Should be only owner");

      _;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    function getOwnerCandidate() public view returns (address) {
        return _ownerCandidate;
    }

    function requestOwnerCandidate(address ownerCandidate) public onlyOwner returns (bool) {
        _ownerCandidate = ownerCandidate;

        emit LogRequestOwnerCandidate(msg.sender, ownerCandidate);

        return true;
    }

    function acceptOwnerCandidate() public returns (bool) {
        require(msg.sender != address(0), "Sender address should be valid");
        require(msg.sender == _ownerCandidate, "Sender should be owner candidate");

        _owner = msg.sender;

        emit LogAcceptOwnerCandidate(msg.sender, msg.sender);

        return true;
    }

    function revokeOwnerCandidate() public onlyOwner returns (bool) {
        emit LogRevokeOwnerCandidate(msg.sender, _ownerCandidate);

        _ownerCandidate = address(0);

        return true;
    }
}
