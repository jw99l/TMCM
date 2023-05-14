pragma solidity 0.8.11;

contract MEVBoostVerifyer {
    bytes32 [65] zeroHashes;

    constructor () {
        // for merkleize zero
        for(uint256 i=0;i<64;i++){
            zeroHashes[i+1] = sha256(abi.encodePacked(zeroHashes[i], zeroHashes[i]));
        }
    }

    // https://github.com/ethereum/consensus-specs/blob/dev/specs/bellatrix/beacon-chain.md#executionpayloadheader
    /*
        class ExecutionPayloadHeader(Container):
            # Execution block header fields
            parent_hash: Hash32
            fee_recipient: ExecutionAddress
            state_root: Bytes32
            receipts_root: Bytes32
            logs_bloom: ByteVector[BYTES_PER_LOGS_BLOOM]
            prev_randao: Bytes32
            block_number: uint64
            gas_limit: uint64
            gas_used: uint64
            timestamp: uint64
            extra_data: ByteList[MAX_EXTRA_DATA_BYTES]
            base_fee_per_gas: uint256
            # Extra payload fields
            block_hash: Hash32  # Hash of execution block
            transactions_root: Root
    */
    struct ExecutionPayloadHeader {
        bytes32 parentHash;
        address feeRecipient;
        bytes32 stateRoot;
        bytes32 receiptsRoot;
        bytes logsBloom;
        bytes32 prevRandao;
        uint256 blockNumber;
        uint256 gasLimit;
        uint256 gasUsed;
        uint256 timestamp;
        bytes extraData;
        uint256 baseFeePerGas;
        bytes32 blockHash;
        bytes32 transactionsRoot;
    }

    function executionPayloadHeaderHash(ExecutionPayloadHeader memory eph) public view returns(bytes32) {
        bytes32 extraDataHash;
        extraDataHash = sha256(abi.encodePacked(bytes32(eph.extraData), (eph.extraData.length << (256-8))));
        // return extraDataHash;

        bytes memory data = abi.encodePacked(eph.parentHash, 
            bytes32(uint256(uint160(eph.feeRecipient))), 
            eph.stateRoot, 
            eph.receiptsRoot, 
            merkleRoot(eph.logsBloom), 
            eph.prevRandao);

        data = abi.encodePacked(data,
            toLittleEndianBytes(eph.blockNumber),
            toLittleEndianBytes(eph.gasLimit), 
            toLittleEndianBytes(eph.gasUsed), 
            toLittleEndianBytes(eph.timestamp), 
            extraDataHash, // eph.extraData, 
            toLittleEndianBytes(eph.baseFeePerGas), 
            eph.blockHash, 
            eph.transactionsRoot);

        return merkleRoot(data);
    }

    function toLittleEndianBytes(uint256 x) public pure returns (bytes memory) {
        bytes32 bigEndianValue = bytes32(x);
        bytes memory littleEndianBytes = new bytes(32);
        
        for (uint8 i = 0; i < 32; i++) {
            littleEndianBytes[i] = bigEndianValue[31 - i];
        }
        
        return littleEndianBytes;
    }

    function getDepth(uint256 numberOfLeaves) public pure returns (uint256) {
        require(numberOfLeaves > 0, "Number of leaves should be greater than zero");

        uint256 height = 0;
        while (numberOfLeaves > 1) {
            numberOfLeaves = (numberOfLeaves + 1) / 2;
            height++;
        }
        
        return height;
    }
    
    function padTo32Bytes(bytes memory input) public pure returns (bytes memory) {
        uint256 paddingLength = 32 - (input.length % 32);
        if (paddingLength == 32) {
            return input;
        }
        
        bytes memory padded = new bytes(paddingLength);
        return abi.encodePacked(input, padded);
    }

    function merkleRoot(bytes memory input) public view returns (bytes32) {
        if(input.length % 32 != 0){
            input = padTo32Bytes(input);
        }

        uint256 layerLen = input.length / 32;
        uint256 depth = getDepth(layerLen);
        bytes32[] memory hashes = new bytes32[](layerLen+100);
        bytes32 zeroHash = bytes32(0);

        for (uint256 i = 0; i < layerLen; i++) {
            bytes32 current;
            assembly {
                current := mload(add(input, add(0x20, mul(i, 0x20))))
            }
            hashes[i] = current;
        }

        for (uint8 i = 0; i < depth; i++) {
            bool oddNodeLength = layerLen % 2 == 1;

            if (oddNodeLength) {
                hashes[layerLen] = zeroHashes[i];
                layerLen++;
            }
            // if(i == 2) return hashes;

            for (uint256 j = 0; j < layerLen; j += 1) {
                hashes[j] = sha256(abi.encodePacked(hashes[j*2], hashes[(j*2)+1]));
            }

            layerLen /= 2;
        }

        return hashes[0];
    }

    function TestVerifySignedBuilderBidSignatureAndWriteHashTreeRoot() public view returns(bytes32) {
        uint value;
        bytes memory pubKey = hex"b5246e299aeb782fbc7c91b41b3284245b1ed5206134b0028b81dfb974e5900616c67847c2354479934fc4bb75519ee1";

        ExecutionPayloadHeader memory eph;
        eph.parentHash = 0x0544e2170998060d9560fdbf8f263a08c0a209211569a0560138522b84805abc;
        eph.feeRecipient = 0x0000000000000000000000000000000000000000;
        eph.stateRoot = 0xcded53d652660a91bfe6f5dfb017204a4cdd1598a07116b2cdea1586d603d01c;
        eph.receiptsRoot = 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421;
        eph.logsBloom = hex"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
        eph.prevRandao = 0xd60955dc7f0cc7bf28d7e6c6f4859081f3a6df5ef4f70e05d70d8282bac20c6c;
        eph.blockNumber = 960335;
        eph.gasLimit = 30000000;
        eph.gasUsed = 0;
        eph.timestamp = 1659720144;
        eph.extraData = hex"466c617368626f747320666c617368626c6f636b";
        eph.baseFeePerGas = 7;
        eph.blockHash = 0xea33078b00e6b2926f45ed6d3190a3a6ada75cee342f600cf22fa02a9a2edcb7;
        eph.transactionsRoot = 0x7ffe241ea60187fdb0187bfa22de35d1f9bed7ab061d9401fd47e34a54fbede1;
        
        bytes32 ephHash = executionPayloadHeaderHash(eph);

        bytes32 rootHash = merkleRoot(abi.encodePacked(ephHash, value, merkleRoot(pubKey)));
        return rootHash;
    }
}
