#!/usr/bin/env python3
"""Read-only transaction receipt collection for Polygon Amoy (chain ID 80002).

Uses public RPC; no wallet, private key, packages or fees required.
"""
import csv
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from decimal import Decimal
from urllib.request import Request, urlopen

# Define input and output file paths
FOLDER = os.path.dirname(os.path.abspath(__file__))
INPUT = os.path.join(FOLDER, 'transaction_input.csv')
# Keep reproduced results separate from original results
NEW_OUTPUT = os.path.join(FOLDER, "reproduced")
os.makedirs(NEW_OUTPUT, exist_ok=True)
OUTPUT = os.path.join(NEW_OUTPUT, 'gas_results.csv')
SUMMARY = os.path.join(NEW_OUTPUT, 'gas_summary.txt')

# These are THIRD-PARTY public read-only RPC nodes, not the deprecated Polygon-operated endpoint.
RPC_URLS = [
    'https://polygon-amoy.drpc.org',
    'https://polygon-amoy-bor-rpc.publicnode.com',
    'https://polygon-amoy.api.onfinality.io/public',
]


# Send a JSON-RPC request to the blockchain
def rpc(url, method, params):
    payload = json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}).encode('utf-8')
    req = Request(url, data=payload, headers={'Content-Type': 'application/json', 'User-Agent': 'Group17-Amoy-Gas-Report/1.0'})
    with urlopen(req, timeout=14) as response:
        data = json.load(response)
    if data.get('error'):
        raise ValueError(str(data['error']))
    return data.get('result')


# Convert hexadecimal values to integers
def as_int(value):
    return int(value, 16) if isinstance(value, str) and value.startswith('0x') else int(value)


# Retrieve a receipt using available RPC endpoints
def receipt_for(tx_hash, urls):
    last_error = None
    for url in urls:
        try:
            result = rpc(url, 'eth_getTransactionReceipt', [tx_hash])
            if result is None:
                last_error = f'No receipt returned by {url}'
                continue
            return result, url, None
        except Exception as exc:
            last_error = str(exc)
    return None, None, last_error or 'No receipt'


def main():
    # Load transaction hashes from the input CSV
    if not os.path.isfile(INPUT):
        sys.exit(f'Input CSV not found: {INPUT}')
    with open(INPUT, newline='', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        original_fields = list(reader.fieldnames or [])
        rows = list(reader)
    if not rows or 'Transaction Hash' not in original_fields:
        sys.exit('Input CSV has no Transaction Hash column or transactions.')

    print(f'Loaded {len(rows)} exported transactions.')
    # Check RPC availability and verify the chain ID
    good_urls = []
    for url in RPC_URLS:
        try:
            chain_id = as_int(rpc(url, 'eth_chainId', []))
            if chain_id == 80002:
                good_urls.append(url)
                print(f'  Amoy RPC OK: {url}')
            else:
                print(f'  SKIPPING wrong chain ({chain_id}): {url}')
        except Exception as exc:
            print(f'  RPC unavailable: {url}: {exc}')
    if not good_urls:
        sys.exit('No Polygon Amoy RPC available. Check internet, then run again. No output changed.')

    # Collect transaction receipts in parallel
    receipt_map = {}
    hashes = list(dict.fromkeys(row['Transaction Hash'].strip() for row in rows if row.get('Transaction Hash', '').strip()))
    with ThreadPoolExecutor(max_workers=3) as pool:
        future_map = {pool.submit(receipt_for, h, good_urls): h for h in hashes}
        for future in as_completed(future_map):
            tx_hash = future_map[future]
            result, url, err = future.result()
            receipt_map[tx_hash] = (result, url, err)
            if result is not None:
                print(f"  OK   {tx_hash[:12]}...  gas={as_int(result['gasUsed'])}")
            else:
                print(f'  MISS {tx_hash[:12]}...  {err}')

    extra = [
        'Gas Used', 'Effective Gas Price (Gwei)', 'Calculated Receipt Fee (POL)',
        'Receipt Status', 'RPC Source', 'PolygonScan Tx Link', 'Collection Note'
    ]
    completed = 0
    for row in rows:
        tx_hash = row.get('Transaction Hash', '').strip()
        receipt, url, err = receipt_map.get(tx_hash, (None, None, 'Missing hash'))
        row['PolygonScan Tx Link'] = f'https://amoy.polygonscan.com/tx/{tx_hash}' if tx_hash else ''
        if receipt is None:
            row['Collection Note'] = str(err)
            for k in extra[:-1]:
                if k != 'PolygonScan Tx Link':
                    row[k] = ''
            continue
        # Extract gas usage and transaction status
        gas = as_int(receipt['gasUsed'])
        row['Gas Used'] = gas
        row['Receipt Status'] = 'Success' if as_int(receipt.get('status', '0x1')) == 1 else 'Failed'
        row['RPC Source'] = url
        if receipt.get('effectiveGasPrice') is not None:
            # Calculate gas price in Gwei and fee in POL
            gas_price = as_int(receipt['effectiveGasPrice'])
            row['Effective Gas Price (Gwei)'] = str(Decimal(gas_price) / Decimal(10**9))
            row['Calculated Receipt Fee (POL)'] = str(Decimal(gas * gas_price) / Decimal(10**18))
            # Compare the calculated fee with the explorer fee
            exported_fee = row.get('TxnFee(POL)', '').strip()
            if exported_fee:
                difference = abs(Decimal(exported_fee) - Decimal(row['Calculated Receipt Fee (POL)']))
                row['Collection Note'] = 'Matches explorer fee' if difference < Decimal('0.00000001') else f'Fee differs from export by {difference} POL'
            else:
                row['Collection Note'] = 'Receipt collected; explorer fee missing'
        else:
            row['Effective Gas Price (Gwei)'] = ''
            row['Calculated Receipt Fee (POL)'] = ''
            row['Collection Note'] = 'Receipt has Gas Used but no effectiveGasPrice'
        completed += 1

    # Save the collected receipts to a CSV file
    with open(OUTPUT, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=original_fields + extra, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)

    # Group transactions by method for gas analysis
    groups = {}
    for row in rows:
        method = row.get('Method') or 'Contract Deployment'
        key = method if method != '0x60806040' else 'Contract Deployment'
        g = groups.setdefault(key, {'count': 0, 'gas': [], 'fee': Decimal(0)})
        g['count'] += 1
        if row['Gas Used'] != '':
            g['gas'].append(int(row['Gas Used']))
        fee_str = row.get('TxnFee(POL)', '').strip()
        if fee_str:
            g['fee'] += Decimal(fee_str)
    lines = [
        'GROUP 17 - POLYGON AMOY GAS ANALYSIS',
        f'Input transactions: {len(rows)} (including deployment if exported)',
        f'Receipts successfully collected: {completed}/{len(rows)}',
        'Network: Polygon Amoy; chain ID 80002',
        'Fees are TEST POL (not real USD costs).',
        '',
        'Method | Exported tx count | Gas observations | Avg Gas Used | Total exported fee (POL)',
    ]
    for method, g in groups.items():
        avg = str(round(sum(g['gas']) / len(g['gas']), 2)) if g['gas'] else 'not available'
        lines.append(f"{method} | {g['count']} | {len(g['gas'])} | {avg} | {g['fee']}")
    lines += ['', 'Gas Used = receipt.gasUsed', 'Effective Gas Price (Gwei) = receipt.effectiveGasPrice / 10^9', 'Fee (POL) = gasUsed * effectiveGasPrice / 10^18', 'Do not mix testnet gas with Hardhat local benchmark results.']
    # Save the gas analysis summary
    with open(SUMMARY, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print(f'\nDone: {completed}/{len(rows)} receipts collected.')
    print(f'Send these files to your teammate:\n  {OUTPUT}\n  {SUMMARY}')
    if completed != len(rows):
        print('Some receipts were unavailable: check Collection Note in the CSV and rerun later.')


if __name__ == '__main__':
    main()
