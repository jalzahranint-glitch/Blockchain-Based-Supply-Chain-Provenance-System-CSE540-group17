import React, { useEffect, useRef, useState } from 'react'
import { ZeroAddress, ZeroHash, formatEther } from 'ethers'
import { ADDRESS, CHAIN_ID, EXPLORER, NETWORK, ROLES, STATUSES, productId, walletAddress, dataHash, explain, providerFor, contractFor } from './contract'
import './index.css'

const SHORT = (address) => address ? `${address.slice(0, 6)}…${address.slice(-4)}` : '—'
const SAME = (a, b) => Boolean(a && b && a.toLowerCase() === b.toLowerCase())
const initialSession = { account: '', chain: '', ready: false, role: 0, admin: '', pending: '', balance: '' }
const tabs = ['Find Product', 'Register Product', 'Transfer Custody', 'Update Status', 'IoT Verification', 'Administration']

  function IdField() { return <label>Product ID<input name="id" inputMode="numeric" pattern="[1-9][0-9]*" required placeholder="For example, 1001" /></label> }
  function AddressField({ label = 'Next custodian’s wallet address', name = 'address' }) { return <label>{label}<input name={name} required placeholder="0x… (full wallet address)" /></label> }

export default function App() {
  const [tab, setTab] = useState(tabs[0])
  const [wallet, setWallet] = useState(null)
  const [session, setSession] = useState(initialSession)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState(null)
  const [tx, setTx] = useState(null)
  const [product, setProduct] = useState(null)
  const [hash, setHash] = useState('')
  const [fileName, setFileName] = useState('')
  const [verification, setVerification] = useState(null)
  const [hashing, setHashing] = useState(false)
  const fileVersion = useRef(0)
  const epoch = useRef(0)
  const inFlight = useRef(false)
  const isAdmin = SAME(session.account, session.admin)
  const isPending = SAME(session.account, session.pending)
  const onAmoy = session.chain === NETWORK.chainId

  // Prefer MetaMask's EIP-6963 announcement if several wallets are installed.
  useEffect(() => {
    function announced(event) {
      if (event.detail.info.rdns === 'io.metamask') setWallet(event.detail.provider)
    }
    window.addEventListener('eip6963:announceProvider', announced)
    window.dispatchEvent(new Event('eip6963:requestProvider'))
    if (window.ethereum?.isMetaMask) setWallet(window.ethereum)
    return () => window.removeEventListener('eip6963:announceProvider', announced)
  }, [])

  async function sync(providerWallet) {
    const version = ++epoch.current
    const provider = providerFor(providerWallet)
    setSession(initialSession)
    setProduct(null)
    setVerification(null)
    try {
      const [accounts, chain] = await Promise.all([
        providerWallet.request({ method: 'eth_accounts' }),
        providerWallet.request({ method: 'eth_chainId' }),
      ])
      if (version !== epoch.current) return
      const account = accounts[0] || ''
      const base = { ...initialSession, account, chain }
      setSession(base)
      if (BigInt(chain) !== CHAIN_ID) return
      if (await provider.getCode(ADDRESS) === '0x') throw new Error('No contract code found at the configured address on Amoy. Confirm the address with your team.')
      const contract = contractFor(provider)
      const [admin, pending, role, balance] = await Promise.all([
        contract.administrator(), contract.pendingAdministrator(),
        account ? contract.getParticipantRole(account) : 0,
        account ? provider.getBalance(account) : 0n,
      ])
      if (version === epoch.current) setSession({ ...base, ready: true, admin, pending, role: Number(role), balance: formatEther(balance) })
    } catch (error) {
      if (version === epoch.current) setNotice({ type: 'error', text: explain(error) })
    } finally { provider.destroy() }
  }

  useEffect(() => {
    if (!wallet) return
    const changed = () => { setNotice(null); void sync(wallet) }
    const disconnected = () => {
      epoch.current++
      setSession(initialSession); setProduct(null); setVerification(null)
      setNotice({ type: 'error', text: 'Wallet disconnected. Reconnect to continue.' })
    }
    wallet.on('accountsChanged', changed)
    wallet.on('chainChanged', changed)
    wallet.on('disconnect', disconnected)
    void sync(wallet)
    return () => {
      epoch.current++
      wallet.removeListener('accountsChanged', changed)
      wallet.removeListener('chainChanged', changed)
      wallet.removeListener('disconnect', disconnected)
    }
  }, [wallet])

  async function run(action) {
    if (inFlight.current) return
    inFlight.current = true
    setBusy(true); setNotice(null)
    try { await action() }
    catch (error) { setNotice({ type: 'error', text: explain(error) }) }
    finally { inFlight.current = false; setBusy(false) }
  }

  async function connect() {
    await run(async () => {
      if (!wallet) throw new Error('MetaMask is not detected. Open the extension in this browser and refresh the page.')
      await wallet.request({ method: 'eth_requestAccounts' })
      await sync(wallet)
    })
  }

  async function switchNetwork() {
    await run(async () => {
      if (!wallet) throw new Error('Install and open MetaMask first.')
      try { await wallet.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: NETWORK.chainId }] }) }
      catch (error) {
        if ((error.code ?? error.data?.originalError?.code) !== 4902) throw error
        await wallet.request({ method: 'wallet_addEthereumChain', params: [NETWORK] })
        await wallet.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: NETWORK.chainId }] })
      }
      await sync(wallet)
    })
  }

  async function checkedProvider() {
    if (!wallet) throw new Error('Connect MetaMask first.')
    if (BigInt(await wallet.request({ method: 'eth_chainId' })) !== CHAIN_ID) throw new Error('Switch MetaMask to Polygon Amoy first.')
    return providerFor(wallet)
  }

  async function getDetails(contract, id) {
    const [p, recordedHash] = await Promise.all([contract.getProduct(id), contract.productIoTHashes(id)])
    return { id: p.id.toString(), producer: p.producer, custodian: p.currentCustodian, status: Number(p.status), metadata: p.metadataURI, recordedHash }
  }

  async function lookup(event) {
    event.preventDefault()
    const input = new FormData(event.currentTarget).get('id')
    setProduct(null)
    await run(async () => {
      const id = productId(input)
      const version = epoch.current
      const provider = await checkedProvider()
      try {
        const details = await getDetails(contractFor(provider), id)
        if (version !== epoch.current) return
        setProduct(details)
        setNotice({ type: 'success', text: 'Product loaded from Polygon Amoy.' })
      } finally { provider.destroy() }
    })
  }

  // Every write is simulated first, then MetaMask asks the user to approve it.
  async function submit(event, method, makeArgs) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    await run(async () => {
      setTx(null)
      const args = makeArgs(form)
      const expectedAccount = session.account
      if (!expectedAccount) throw new Error('Connect your wallet first.')
      const provider = await checkedProvider()
      try {
        const signer = await provider.getSigner()
        if (!SAME(await signer.getAddress(), expectedAccount)) throw new Error('Your wallet account changed. Check the displayed account and try again.')
        const contract = contractFor(signer)
        // Reads plus the contract's static call enforce current on-chain rules.
        if (method === 'updateStatus') {
          const p = await contract.getProduct(args[0])
          const next = Number(p.status) + 1
          if (next > 3) throw new Error('This product is already Delivered.')
          args.push(next)
        }
        await contract[method].staticCall(...args)
        setNotice({ type: 'info', text: 'Review and approve this transaction in MetaMask.' })
        const sent = await contract[method](...args)
        setTx({ hash: sent.hash, status: 'Pending' })
        setNotice({ type: 'info', text: 'Transaction submitted. Waiting for confirmation; do not submit it again.' })
        let receipt
        try { receipt = await sent.wait() }
        catch (error) {
          if (error.code === 'TRANSACTION_REPLACED') {
            setTx({ hash: error.replacement.hash, status: error.cancelled ? 'Cancelled / replaced' : 'Confirmed replacement' })
            if (error.cancelled) throw new Error('Transaction was cancelled or replaced in MetaMask. Check its explorer receipt.')
            receipt = error.receipt
          } else {
            setTx({ hash: sent.hash, status: error.receipt ? 'Failed' : 'Confirmation unknown — check explorer' })
            throw error
          }
        }
        if (!receipt || receipt.status !== 1) throw new Error('Transaction failed. Check the explorer receipt.')
        setTx({ hash: receipt.hash, status: 'Confirmed' })
        await sync(wallet)
        setNotice({ type: 'success', text: `${method} confirmed. Use Find Product to view the latest record.` })
      } finally { provider.destroy() }
    })
  }

  async function hashFile(event) {
    const file = event.target.files[0]
    const version = ++fileVersion.current
    setHash(''); setVerification(null); setFileName(file?.name || '')
    if (!file) { setHashing(false); return }
    if (file.size > 10 * 1024 * 1024) { setNotice({ type: 'error', text: 'Choose a file smaller than 10 MB.' }); return }
    setHashing(true)
    try {
      const result = await crypto.subtle.digest('SHA-256', await file.arrayBuffer())
      if (version === fileVersion.current) setHash('0x' + Array.from(new Uint8Array(result), b => b.toString(16).padStart(2, '0')).join(''))
    } catch (error) { setNotice({ type: 'error', text: explain(error) }) }
    finally { if (version === fileVersion.current) setHashing(false) }
  }

  async function verify(event) {
    event.preventDefault()
    const input = new FormData(event.currentTarget)
    setVerification(null)
    await run(async () => {
      const id = productId(input.get('id')); const digest = dataHash(hash)
      const version = epoch.current
      const provider = await checkedProvider()
      try {
        const contract = contractFor(provider)
        const [matches, stored] = await Promise.all([contract.verifyIoTHash(id, digest), contract.productIoTHashes(id)])
        if (version === epoch.current) setVerification(stored === ZeroHash ? 'No IoT hash has been recorded for this product.' : matches ? 'MATCH: This file/hash matches the recorded hash.' : 'MISMATCH: This file/hash differs from the recorded hash.')
      } finally { provider.destroy() }
    })
  }

  const writeDisabled = busy || !session.ready || !session.account
  function Button({ children, disabled = writeDisabled }) { return <button className="primary-button" disabled={disabled}>{busy ? 'Please wait…' : children}</button> }

  return <div className="app">
    <header className="header"><div className="brand"><span className="brand-icon">SC</span><div><strong>SupplyTrace</strong><span className="subtitle">Supply Chain Provenance</span></div></div>
      <div className="wallet-controls"><span className="badge">{onAmoy ? 'Polygon Amoy' : 'Amoy required'}</span><button className="outline-button" onClick={connect} disabled={busy} title={session.account}>{session.account ? `Connected: ${SHORT(session.account)}` : 'Connect Wallet'}</button></div>
    </header>
    <main><section className="hero"><p className="eyebrow">CSE 540 · GROUP 17</p><h1>Every product has a journey.</h1><p>Track product origins, custody transfers, and delivery status through your supply chain.</p></section>
    <section className="journey" aria-label="Supply chain participants">{ROLES.slice(1, 5).map((role, i) => <div className="journey-step" key={role}><span className="step-number">{i + 1}</span><strong>{role}</strong></div>)}</section>
    <section className="connection-card">
      <div><strong>{session.ready ? 'Contract connected' : 'Connect to the project network'}</strong><p>{session.ready ? `Your role: ${ROLES[session.role]}${isAdmin ? ' · Administrator' : ''}${isPending ? ' · Nominated administrator' : ''}` : 'Use MetaMask on Polygon Amoy to load the contract.'}</p>
      {session.account && <p className="address">Wallet: {session.account}</p>}
      {session.ready && session.account && <p>Balance: {Number(session.balance).toFixed(5)} test POL</p>}</div>
      <div className="connection-actions">{!onAmoy && <button className="outline-button" onClick={switchNetwork} disabled={busy || !wallet}>Switch / add Amoy</button>}<button className="outline-button" disabled={busy || !wallet} onClick={() => run(() => sync(wallet))}>Refresh connection / role</button></div>
    </section>
    {session.ready && session.account && session.role === 0 && <div className="notice">Your wallet has no participant role yet. You can read products. Ask the contract administrator to assign Producer if you will register products.</div>}
    {notice && <div className={`notice ${notice.type}`} role={notice.type === 'error' ? 'alert' : 'status'}>{notice.text}</div>}
    {tx && <div className="notice" role="status">{tx.status}: <a href={`${EXPLORER}/tx/${tx.hash}`} target="_blank" rel="noreferrer">View transaction receipt</a></div>}
    <section className="workspace"><nav className="navigation" aria-label="Product actions">{tabs.map(item => <button key={item} disabled={busy} className={`nav-button ${tab === item ? 'active' : ''}`} aria-pressed={tab === item} onClick={() => { setTab(item); setNotice(null) }}>{item}</button>)}</nav>
    <div className="panel"><h2>{tab}</h2>
    {tab === 'Find Product' && <><p>Read a product’s current on-chain details. No transaction fee.</p><form onSubmit={lookup}><IdField /><Button disabled={busy || !session.ready}>Find Product</Button></form>
      {product && <section className="result"><div className="result-heading"><h3>Product #{product.id}</h3><span className="badge">{STATUSES[product.status]}</span></div><dl><dt>Producer</dt><dd>{product.producer}</dd><dt>Current custodian</dt><dd>{product.custodian}</dd><dt>Metadata reference</dt><dd>{product.metadata}</dd><dt>Latest IoT hash</dt><dd>{product.recordedHash === ZeroHash ? 'Not recorded' : product.recordedHash}</dd></dl></section>}</>}
    {tab === 'Register Product' && <><p>Only an assigned Producer can register a new, unique product ID.</p><form onSubmit={e => submit(e, 'registerProduct', f => {
      const metadata = String(f.get('metadata')).trim(); if (!metadata) throw new Error('Enter a metadata reference.'); return [productId(f.get('id')), metadata]
    })}><IdField /><label>Metadata reference<input name="metadata" required placeholder="ipfs://… or https://…" /></label><p className="field-help">This stores a reference, not a file upload. Use an existing reference; label demonstration-only references clearly.</p><Button disabled={writeDisabled || session.role !== 1}>Register Product</Button></form></>}
    {tab === 'Transfer Custody' && <><p>The current custodian transfers to the next role. Status stays unchanged.</p><p className="field-help">Created: Producer → Transporter · Shipped: Transporter → Warehouse · Received: Warehouse → Retailer.</p><form onSubmit={e => submit(e, 'transferCustody', f => [productId(f.get('id')), walletAddress(f.get('address'))])}><IdField /><AddressField /><Button disabled={writeDisabled || ![1, 2, 3].includes(session.role)}>Transfer Custody</Button></form></>}
    {tab === 'Update Status' && <><p>The contract allows only the next status, set by the current custodian with the required role.</p><p className="field-help">Transporter → Shipped · Warehouse → Received · Retailer → Delivered.</p><form onSubmit={e => submit(e, 'updateStatus', f => [productId(f.get('id'))])}><IdField /><Button disabled={writeDisabled || ![2, 3, 4].includes(session.role)}>Advance to Next Status</Button></form></>}
    {tab === 'IoT Verification' && <><p>Check a local file against the latest SHA-256 hash stored for a product.</p><label>Choose a sensor data file<input type="file" disabled={busy} onChange={hashFile} /></label><p className="field-help">{hashing ? 'Calculating SHA-256…' : fileName || 'The file stays on this computer. Only its hash can be recorded.'} We hash exact file bytes, so even whitespace changes affect the result.</p>
      <label>SHA-256 hash<input value={hash} disabled={busy || hashing} onChange={e => { fileVersion.current++; setHash(e.target.value); setFileName(''); setVerification(null) }} placeholder="Paste 64 hex characters, or choose a file" /></label>
      <form onSubmit={verify}><IdField /><Button disabled={busy || hashing || !session.ready || !hash}>Verify Hash (read only)</Button></form>
      {verification && <div className="notice" role="status">{verification}</div>}
      <details><summary>Record this hash on-chain</summary><p>Only the current authorized custodian can record it. This replaces the product’s latest stored hash and requires a transaction.</p><form onSubmit={e => submit(e, 'recordIoTHash', f => [productId(f.get('id')), dataHash(hash)])}><IdField /><Button disabled={writeDisabled || hashing || !hash || ![1, 2, 3, 4].includes(session.role)}>Record Hash</Button></form></details>
      <p className="field-help">A matching hash proves consistency with the stored fingerprint, not that the original sensor reading was accurate.</p></>}
    {tab === 'Administration' && <><p>Administrator: <span className="address">{session.admin || 'Not loaded'}</span></p><p>Pending administrator: <span className="address">{session.pending && session.pending !== ZeroAddress ? session.pending : 'None'}</span></p>
      {!isAdmin && <p className="notice">Only the current administrator can assign roles or recover custody.</p>}
      {isPending && <form onSubmit={e => submit(e, 'acceptAdministration', () => [])}><Button>Accept Administration</Button></form>}
      {isAdmin && <><h3>Assign participant role</h3><form onSubmit={e => submit(e, 'setParticipantRole', f => [walletAddress(f.get('address')), Number(f.get('role'))])}><AddressField label="Participant wallet address" /><label>Role<select name="role" defaultValue="1">{ROLES.map((role, i) => <option key={role} value={i}>{role}{i === 0 ? ' (remove access)' : ''}</option>)}</select></label><Button>Assign Role</Button></form>
      <details><summary>Recover custody</summary><p>Allowed only if the current custodian has lost the required role. The replacement must hold that same required role.</p><form onSubmit={e => submit(e, 'adminReassignCustody', f => [productId(f.get('id')), walletAddress(f.get('address'))])}><IdField /><AddressField /><Button>Reassign Custody</Button></form></details>
      <details><summary>Transfer administration</summary><p>Nominate a wallet. That wallet must connect and accept before control transfers. Use the zero address to cancel a nomination.</p><form onSubmit={e => submit(e, 'transferAdministration', f => [walletAddress(f.get('address'), true)])}><AddressField label="New administrator address" /><Button>Nominate Administrator</Button></form></details></>}
    </>}
    </div></section>
    <footer><p>Contract: <a href={`${EXPLORER}/address/${ADDRESS}`} target="_blank" rel="noreferrer">{ADDRESS}</a></p><p>Polygon Amoy testnet · Group 17 · CSE 540</p></footer>
    </main></div>
}
