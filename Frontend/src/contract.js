import { BrowserProvider, Contract, isAddress, ZeroAddress } from 'ethers'
// Public deployment information supplied by the team. Never put private keys here.
export const ADDRESS = '0xb038fc9d3922f8dd06085b0d3548d30b90a82e67'
export const CHAIN_ID = 80002n
export const EXPLORER = 'https://amoy.polygonscan.com'
export const NETWORK = {
  chainId: '0x13882', chainName: 'Polygon Amoy Testnet',
  nativeCurrency: { name: 'POL', symbol: 'POL', decimals: 18 },
  rpcUrls: ['https://rpc-amoy.polygon.technology/'], blockExplorerUrls: [EXPLORER],
}
// Human-readable ABI derived from the Solidity source in the updated team ZIP.
// These are the actual argument and return types, not a separate contract.
export const ABI = [
  'function administrator() view returns (address)',
  'function pendingAdministrator() view returns (address)',
  'function getParticipantRole(address participant) view returns (uint8)',
  'function setParticipantRole(address participant,uint8 role)',
  'function getProduct(uint256 productId) view returns (tuple(uint256 id,address producer,address currentCustodian,uint8 status,string metadataURI,bool exists))',
  'function registerProduct(uint256 productId,string metadataURI)',
  'function transferCustody(uint256 productId,address newCustodian)',
  'function updateStatus(uint256 productId,uint8 newStatus)',
  'function productIoTHashes(uint256) view returns (bytes32)',
  'function recordIoTHash(uint256 productId,bytes32 dataHash)',
  'function verifyIoTHash(uint256 productId,bytes32 dataHash) view returns (bool)',
  'function adminReassignCustody(uint256 productId,address newCustodian)',
  'function transferAdministration(address newAdministrator)',
  'function acceptAdministration()',
]
export const ROLES = ['Unassigned', 'Producer', 'Transporter', 'Warehouse', 'Retailer', 'Viewer']
export const STATUSES = ['Created', 'Shipped', 'Received', 'Delivered']
export function productId(value) {
  const text = String(value).trim()
  if (!/^[1-9][0-9]*$/.test(text)) throw new Error('Enter a positive whole-number product ID.')
  const id = BigInt(text)
  if (id >= 2n ** 256n) throw new Error('Product ID is too large.')
  return id
}
export function walletAddress(value, allowZero = false) {
  const address = value.trim()
  if (!isAddress(address) || (!allowZero && address.toLowerCase() === ZeroAddress)) {
    throw new Error('Enter a valid Ethereum wallet address (0x followed by 40 hexadecimal characters).')
  }
  return address
}
export function dataHash(value) {
  const hash = value.trim().replace(/^0x/i, '')
  if (!/^[a-f0-9]{64}$/i.test(hash) || /^0+$/.test(hash)) throw new Error('Enter a nonzero SHA-256 hash: 64 hexadecimal characters.')
  return '0x' + hash
}
export function explain(error) {
  const code = error.code ?? error.info?.error?.code
  if (code === 4001 || code === 'ACTION_REJECTED') return 'Request cancelled in MetaMask. Nothing was submitted by this request.'
  if (code === -32002) return 'A request is already waiting. Open MetaMask to respond.'
  if (code === 'INSUFFICIENT_FUNDS') return 'This wallet needs test POL on Amoy to pay the transaction fee.'
  return error.reason || error.info?.error?.message || error.shortMessage || error.message || 'The request failed.'
}
export function providerFor(wallet) { return new BrowserProvider(wallet) }
export function contractFor(provider) { return new Contract(ADDRESS, ABI, provider) }
