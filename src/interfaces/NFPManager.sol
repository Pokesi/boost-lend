// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

interface INFPManager {
  function DOMAIN_SEPARATOR (  ) external view returns ( bytes32 );
  function PERMIT_TYPEHASH (  ) external view returns ( bytes32 );
  function WETH9 (  ) external view returns ( address );
  function approve ( address to, uint256 tokenId ) external;
  function balanceOf ( address owner ) external view returns ( uint256 );
  function baseURI (  ) external pure returns ( string memory );
  function burn ( uint256 tokenId ) external;
  function createAndInitializePoolIfNecessary ( address token0, address token1, uint24 fee, uint160 sqrtPriceX96 ) external returns ( address pool );
  function factory (  ) external view returns ( address );
  function getApproved ( uint256 tokenId ) external view returns ( address );
 function initialize ( address _factory, address _WETH9, address _tokenDescriptor_ ) external;
  function isApprovedForAll ( address owner, address operator ) external view returns ( bool );
  function multicall ( bytes[] memory data ) external returns ( bytes[] memory results );
  function name (  ) external view returns ( string memory );
  function ownerOf ( uint256 tokenId ) external view returns ( address );
  function permit ( address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function positions ( uint256 tokenId ) external view returns ( uint96 nonce, address operator, address token0, address token1, uint24 fee, int24 tickLower, int24 tickUpper, uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1 );
  function ramsesV2MintCallback ( uint256 amount0Owed, uint256 amount1Owed, bytes memory data ) external;
  function refundETH (  ) external;
  function safeTransferFrom ( address from, address to, uint256 tokenId ) external;
  function safeTransferFrom ( address from, address to, uint256 tokenId, bytes memory _data ) external;
  function selfPermit ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function selfPermitAllowed ( address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s ) external;
  function selfPermitAllowedIfNecessary ( address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s ) external;
  function selfPermitIfNecessary ( address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s ) external;
  function setApprovalForAll ( address operator, bool approved ) external;
  function supportsInterface ( bytes4 interfaceId ) external view returns ( bool );
  function sweepToken ( address token, uint256 amountMinimum, address recipient ) external;
  function switchAttachment ( uint256 tokenId, uint256 veRamTokenId ) external;
  function symbol (  ) external view returns ( string memory );
  function tokenByIndex ( uint256 index ) external view returns ( uint256 );
  function tokenOfOwnerByIndex ( address owner, uint256 index ) external view returns ( uint256 );
  function tokenURI ( uint256 tokenId ) external view returns ( string memory );
  function totalSupply (  ) external view returns ( uint256 );
  function transferFrom ( address from, address to, uint256 tokenId ) external;
  function unwrapWETH9 ( uint256 amountMinimum, address recipient ) external;
  function veRam (  ) external view returns ( address );
}
