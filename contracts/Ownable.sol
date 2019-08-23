pragma solidity 0.5.10;

contract Ownable {
    address private _owner;
    address private _ownerCandidate;

    constructor() public {
        _owner = msg.sender;
    }

    event LogOwnerCandidateRequested(address indexed owner, address indexed candidate);
    event LogOwnerCandidateAccepted(address indexed ownerNew);
    event LogOwnerCandidateRevoked(address indexed candidateRevoked);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Should be only owner");

        _;
    }

    modifier whenOwnerCandidateNotRequested {
        require(_ownerCandidate == address(0), "Only owner candidate was not requested");

        _;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    function getOwnerCandidate() public view returns (address) {
        return _ownerCandidate;
    }

    function requestOwnerCandidate(address ownerCandidate) public onlyOwner returns (bool) {
        require(_ownerCandidate == address(0), "Owner candidate should not be set previously");

        _ownerCandidate = ownerCandidate;

        emit LogOwnerCandidateRequested(msg.sender, ownerCandidate);

        return true;
    }

    function acceptOwnerCandidate() public returns (bool) {
        require(msg.sender != address(0), "Sender address should be valid");
        require(msg.sender == _ownerCandidate, "Sender should be owner candidate");

        _owner = msg.sender;
        _ownerCandidate = address(0);

        emit LogOwnerCandidateAccepted(msg.sender);

        return true;
    }

    function revokeOwnerCandidate() public onlyOwner returns (bool) {
        emit LogOwnerCandidateRevoked(_ownerCandidate);

        _ownerCandidate = address(0);

        return true;
    }
}
