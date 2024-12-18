// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {Base64} from "@solady/src/utils/Base64.sol";
import {ERC721} from "@solady/src/tokens/ERC721.sol";
import {Ownable} from "@solady/src/auth/Ownable.sol";
import {LibString} from "@solady/src/utils/LibString.sol";

/// @notice Simple NFT contract for minting bounties.
/// @dev Emojis also used for people that can't read.
contract bounty is ERC721, Ownable {
    using LibString for uint256;

    enum Status {
        None,
        Pending,
        Rejected,
        Approved,
        Completed
    }

    struct Bounty {
        string emojis; // pictoral
        string text; // basic gist
        address token; // to grant
        uint256 amount; // the sum
        Status status; // id state
        address watcher; // admins
    }

    uint256[] public bounties;
    mapping(uint256 tokenId => Bounty) public requests;

    constructor() payable {
        _initializeOwner(tx.origin); // Helps factory.
    }

    function name() public pure override(ERC721) returns (string memory) {
        return "nani bounties";
    }

    function symbol() public pure override(ERC721) returns (string memory) {
        return unicode"⌘";
    }

    error Exists();

    function propose(string calldata emojis, string calldata text)
        public
        returns (uint256 tokenId)
    {
        tokenId = uint256(keccak256(abi.encodePacked(emojis, text)));
        if (requests[tokenId].status != Status.None) revert Exists();
        requests[tokenId] = Bounty(emojis, text, address(0), 0, Status.Pending, owner());
        bounties.push(tokenId);
    }

    function request(
        string calldata emojis,
        string calldata text,
        address token,
        uint256 amount,
        address watcher
    ) public onlyOwner returns (uint256 tokenId) {
        tokenId = uint256(keccak256(abi.encodePacked(emojis, text)));
        _mint(watcher, tokenId);
        requests[tokenId] = Bounty(emojis, text, token, amount, Status.Approved, watcher);
        if (requests[tokenId].status == Status.None) bounties.push(tokenId);
    }

    error NotPending();

    function reject(uint256 tokenId) public onlyOwner {
        if (requests[tokenId].status != Status.Pending) revert NotPending();
        requests[tokenId].status = Status.Rejected;
    }

    error NotApproved();
    error NotWatcher();

    function complete(uint256 tokenId, address recipient) public {
        Bounty storage _bounty = requests[tokenId];
        if (_bounty.status != Status.Approved) revert NotApproved();
        if (_bounty.watcher != msg.sender) revert NotWatcher();
        _bounty.status = Status.Completed;
        _transfer(address(0), ownerOf(tokenId), recipient, tokenId);
    }

    function read() public view returns (uint256[] memory) {
        return bounties;
    }

    function getBountiesByStatus(Status _status) public view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i; i != bounties.length; ++i) {
            if (requests[bounties[i]].status == _status) {
                ++count;
            }
        }

        uint256[] memory filtered = new uint256[](count);
        uint256 index;
        for (uint256 i; i != bounties.length; ++i) {
            if (requests[bounties[i]].status == _status) {
                filtered[index] = bounties[i];
                ++index;
            }
        }

        return filtered;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        string memory svg = _generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Bounty #',
                        tokenId.toString(),
                        '", "description": "nani bounties", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _generateSVG(uint256 tokenId) internal view returns (string memory) {
        Bounty memory _bounty = requests[tokenId];
        uint256 lineLength = 30;
        string[] memory words = _split(_bounty.text, " ");
        string memory wrappedText = "";
        uint256 lineCount;
        string memory currentLine = "";

        for (uint256 i; i != words.length; ++i) {
            if (bytes(currentLine).length + bytes(words[i]).length + 1 > lineLength) {
                wrappedText = string(
                    abi.encodePacked(
                        wrappedText, '<tspan x="175" dy="1.2em">', currentLine, "</tspan>"
                    )
                );
                currentLine = words[i];
                ++lineCount;
            } else {
                if (bytes(currentLine).length != 0) {
                    currentLine = string(abi.encodePacked(currentLine, " "));
                }
                currentLine = string(abi.encodePacked(currentLine, words[i]));
            }
        }
        wrappedText = string(
            abi.encodePacked(wrappedText, '<tspan x="175" dy="1.2em">', currentLine, "</tspan>")
        );

        // Calculate font size based on text length.
        uint256 fontSize = 12;
        if (bytes(_bounty.text).length > 500) fontSize = 10;
        if (bytes(_bounty.text).length > 750) fontSize = 8;

        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350">',
                "<style>",
                ".base { fill: #00FFFF; }",
                '.title { font-family: "Copperplate Gothic", "Times New Roman", serif; font-size: 24px; font-weight: bold; }',
                ".emoji { font-family: Arial, sans-serif; font-size: 32px; }",
                '.text { font-family: "Brush Script MT", "Lucida Calligraphy", cursive; font-style: italic; }',
                ".border { fill: none; stroke: #00FFFF; stroke-width: 2; }",
                "</style>",
                '<rect width="100%" height="100%" fill="black" />',
                '<rect x="10" y="10" width="330" height="330" class="border" />',
                '<text x="175" y="100" class="base emoji" text-anchor="middle">',
                _bounty.emojis,
                "</text>",
                '<text x="175" y="160" class="base text" text-anchor="middle" font-size="',
                fontSize.toString(),
                'px">',
                wrappedText,
                "</text>",
                "</svg>"
            )
        );
    }

    function _split(string memory _base, string memory _delimiter)
        internal
        pure
        returns (string[] memory)
    {
        bytes memory baseBytes = bytes(_base);
        uint256 count = 1;
        for (uint256 i; i != baseBytes.length; ++i) {
            if (baseBytes[i] == bytes(_delimiter)[0]) ++count;
        }
        string[] memory result = new string[](count);
        uint256 index;
        uint256 lastIndex;
        for (uint256 i; i != baseBytes.length; ++i) {
            if (baseBytes[i] == bytes(_delimiter)[0]) {
                result[index] = _substring(_base, lastIndex, i);
                lastIndex = i + 1;
                ++index;
            }
        }
        result[index] = _substring(_base, lastIndex, baseBytes.length);
        return result;
    }

    function _substring(string memory _base, uint256 _start, uint256 _end)
        internal
        pure
        returns (string memory)
    {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _result = new bytes(_end - _start);
        for (uint256 i = _start; i != _end; ++i) {
            _result[i - _start] = _baseBytes[i];
        }
        return string(_result);
    }
}
