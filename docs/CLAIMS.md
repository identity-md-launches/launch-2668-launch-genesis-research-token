# Requester transfer and protocol claims

All actions here take place on Robinhood Chain **4663** after the launch handoff has been
verified. GENS uses 18 decimals. Use the actual GENS address from that handoff; its symbol
alone does not identify the token. The following are separate operations with different
beneficiaries.

## Requester allocation and Genesis reserve

The factory directly delivers **100,000,000 GENS** to the requester/paying wallet
`0x550011cadcc758969391050241b2fc43ed1a4b97`. This allocation needs no claim, unlock, vesting,
or approval. The requester is responsible for the following separate wallet transaction:

| Field | Value |
| --- | --- |
| Sender | `0x550011cadcc758969391050241b2fc43ed1a4b97` |
| Transaction destination | Verified deployed GENS token address from the handoff |
| Function | `transfer(address,uint256)` |
| Recipient argument | `0x4a532cbc877fbbd4950fdab65bfea2e8567b857b` |
| Amount argument | `80000000000000000000000000` (80,000,000 GENS) |
| Native transaction value | `0` |

1. Confirm successful launch, verified token sources, chain ID, and the original requester
   allocation. If the wallet has already moved tokens, reconcile its history before sending.
2. In the requester's wallet, encode the ERC-20 transfer above to the **token contract**.
   The reserve is the argument to `transfer`, not the transaction's contract destination.
   No allowance, fee splitter, or reserve contract is required. The wallet pays normal chain gas.
3. Confirm the transaction succeeded and emitted a `Transfer` from the requester to the exact
   reserve for `80000000000000000000000000` minor units. Record the transaction hash and block.
4. With no other wallet movements, balances must be 80,000,000 GENS at the reserve and
   20,000,000 GENS at the requester. Both are immediately spendable; there is no vesting.

For offline review, this command only encodes the call and does not send a transaction:

```sh
cast calldata 'transfer(address,uint256)' \
  0x4a532cbc877fbbd4950fdab65bfea2e8567b857b \
  80000000000000000000000000
```

Record the completed transfer before retrying any wallet action. A normal ERC-20 transfer has
no special one-time reserve guard; it can be repeated if sufficient funds exist. Neither IMD
nor the token automatically executes or retries this action. Control of the reserve remains
with its wallet holders. The token cannot compel, reverse or recover a wallet transfer.

## Fees from the seeded LP position

The pool's total fee is **1.25%**. The requester owns the entire **80% requester share of the
seeded LP position's collected fees**; the network receives 20%. There is no research reserve
deduction, fee splitter, staking reward or yield promise. Additional liquidity can affect the
seeded position's share of pool-wide fee accrual. Fees may accrue in either pool currency;
neither a fixed income nor conversion to GENS or IMD is guaranteed.

Use the standard protocol's fee-claim interface, not `LaunchToken`. GENS itself has no `claim`
function. Anyone may trigger collection for the recorded beneficiaries; the caller must not
substitute itself or the reserve for the requester.

1. From the authenticated handoff, obtain the factory/fee-claim contract address, verified ABI,
   exact pool key, and seeded LP position/project identifier. Verify that the beneficiary record
   is `0x550011cadcc758969391050241b2fc43ed1a4b97` with the full 80% requester share.
2. Use the handoff's documented read method to inspect claimable fees and simulate its actual
   collection method with those identifiers. No concrete claim signature or claim contract
   address is assumed in this repository because the protocol ABI was not supplied.
3. Submit through the protocol's authenticated claim UI or verified contract interface. Confirm
   the decoded call collects for the fixed requester and network beneficiaries. Normal fee
   collection should not require approving the requester's GENS balance to an unknown contract.
4. Check the receipt, emitted collection records, and beneficiary balance deltas in each currency.
   Confirm the requester receives its whole protocol-assigned share, with no reserve deduction.
   A zero accrual is not an error in the token; follow the claim contract's actual zero-fee behavior.

The protocol controls collection mechanics and integer rounding. Its contracts, position custody
and deployed fee settings must be verified by IMD; local token tests do not establish them. Fee
entitlement is tied to the seeded position's recorded beneficiary, not transferred with ordinary
GENS balances. Sending 80 million GENS to the reserve does not redirect requester fees.

## Swarm token claims

The factory funds its own MerkleDistributor with **100,000,000 GENS**. Under the supplied launch
policy, 20,000,000 GENS (2% of total supply) is shared among accepted contributor wallets, and
80,000,000 GENS (8%) among paired seats at admission. This protocol 8% is distinct from the
requester's separate 8% reserve transfer; both come from the already fixed supply.

Beneficiaries obtain the distributor address, committed root, entitlement, leaf fields and proof
from the authenticated IMD allocation handoff. Verify the distributor's token is this GENS and
use its verified ABI to check claim status, simulate, then submit a claim. Check the successful
receipt and exact token amount received, and retain the receipt to avoid duplicate submissions.
An invalid proof or already-consumed claim must be handled according to that deployed distributor's
implementation. This repository does not invent a leaf format, claims deadline or claim selector,
and does not reimplement the protocol distributor.

The requester allocation and reserve transfer do not depend on Swarm claims. Ordinary GENS
holders have no automatic entitlement to Swarm allocations or seeded LP fees.
