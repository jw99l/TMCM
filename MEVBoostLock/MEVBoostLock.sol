pragma solidity 0.8.11;

import "./MEVBoostVerifyer.sol";

contract MEVBoostLock {
    uint LOCK_BLOCK_COUNT = 32 * 2; // 32 = 1 epoch, finality를 충분히 보장
    
    mapping(address => bytes) public proposerToPubkey;
    mapping(bytes32 => address) public pubkeyToProposer;
    mapping(uint => bool) public usedBlock;

    mapping(address => uint256) public lockdAmounts;
    mapping(address => uint256) public unlockRequestAmounts;
    mapping(address => uint256) public unlockRequestBlock;

    bytes public domainHash;

    MEVBoostVerifyer public mbv;

    address public owner;

    constructor() {
        owner = msg.sender;
        mbv = new MEVBoostVerifyer();
        // domainHash = _domainHash;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    function registProposer(bytes memory pubkey) public {
        require(proposerToPubkey[msg.sender].length == 0, "Already registered"); // unlock 타임 무시용으로 사용될 수 있기 때문에 방지
        require(pubkeyToProposer[keccak256(pubkey)] == address(0), "Already registered"); // unlock 타임 무시용으로 사용될 수 있기 때문에 방지
        proposerToPubkey[msg.sender] = pubkey;
        pubkeyToProposer[keccak256(pubkey)] = msg.sender;
    }

    function lock() public payable {
        lockdAmounts[msg.sender] += msg.value;
    }

    function unlock(uint256 amount) public {
        require(amount > 0, "Amount is zero"); // 언스테이킹은 0보다 커야함
        require(unlockRequestAmounts[msg.sender] == 0, "Unstaking already in progress"); // 언스테이킹이 진행중이지 않아야함

        lockdAmounts[msg.sender] -= amount; // 스테이킹 양에서 차감하고
        unlockRequestAmounts[msg.sender] = amount; // 언스테이킹 수량을 기록하고
        unlockRequestBlock[msg.sender] = block.number; // 언스테이킹 블록을 기록한다
    }

    function withdraw() public {
        require(unlockRequestAmounts[msg.sender] != 0, "Unstaking is not in progress"); // 언스테이킹 내역이 존재하지 않음
        require(block.number >= unlockRequestBlock[msg.sender] + LOCK_BLOCK_COUNT, "Check unstaking block number"); // 언스테이킹 시간이 되지 않음

        uint256 amount = unlockRequestAmounts[msg.sender];
        unlockRequestAmounts[msg.sender] = 0;
        (bool success, bytes memory ret) = payable(msg.sender).call{value: amount}("");
        require(success, "check msg.sender status");
    }

    function slashByOwner(address proposer, address builder) public onlyOwner {
        uint slash_amount = 0;

        slash_amount += lockdAmounts[proposer];
        slash_amount += unlockRequestAmounts[proposer];
        
        lockdAmounts[proposer] = 0;
        unlockRequestAmounts[proposer] = 0;

        (bool success, bytes memory ret) = payable(builder).call{value: slash_amount}("");
        require(success, "check builder status");
    }

    function slashProof(MEVBoostVerifyer.ExecutionPayloadHeader calldata blockHeader, bytes calldata pubKey, uint value, bytes calldata sigBytes) public {
        require(blockHeader.blockNumber > block.number, "future state"); // 배신한 블록은 과거 블록이여야함
        require((block.number - blockHeader.blockNumber) < 256, "lost state"); // ethereum에서 block hash는 256 블록까지 저장됨

        require(blockHeader.blockHash != blockhash(blockHeader.blockNumber), "block is mined normally"); // 블록 빌더가 의도한 블록이 채굴됨
        require(usedBlock[blockHeader.blockNumber] == false, "block used for slash");
        usedBlock[blockHeader.blockNumber] = true;


        bytes32 ephHash = mbv.executionPayloadHeaderHash(blockHeader);
        bytes32 rootHash = mbv.merkleRoot(abi.encodePacked(ephHash, value, mbv.merkleRoot(pubKey)));


        bytes32 msg = mbv.merkleRoot(abi.encodePacked(rootHash, domainHash));
        // require(blsVerifySignatureBytes(msg, sigBytes, pubKey), "verify signature failed");

        address proposer = pubkeyToProposer[keccak256(pubKey)];
        uint slash_amount = 0;

        slash_amount += lockdAmounts[proposer];
        slash_amount += unlockRequestAmounts[proposer];
        
        lockdAmounts[proposer] = 0;
        unlockRequestAmounts[proposer] = 0;
        (bool success, bytes memory ret) = payable(blockHeader.feeRecipient).call{value: slash_amount}("");
    }
}
