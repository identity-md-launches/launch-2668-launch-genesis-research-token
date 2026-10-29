# Review and validation boundaries

## Production surface

The only production contract is `LaunchToken`. Its only project-specific action is the
constructor mint of `1_000_000_000 * 10 ** 18` to `msg.sender`. That address is the factory in
the authorized launch, and gets no ongoing authority. No application contracts or linked
libraries are required. Inherited `_mint` and `_burn` are internal; there is no runtime public
entry point that calls them. The production ABI consists solely of standard ERC-20 functions,
events and errors.

The inherited transfer/approval path makes no external calls, does not invoke recipient hooks,
and uses no external prices or randomness. No reentrancy guard, owner, initialization method,
oracle setting, clock condition or upgrade path is needed. Self transfers and zero amounts
retain ordinary ERC-20 behavior. Solidity/OZ balance checks and transaction rollback protect
both balances and finite allowances on failure.

The token has no recovery function. Tokens deliberately sent to contracts without a withdrawal
path can become inaccessible; approvals authorize their spender until spent or revoked. A
nonzero allowance replacement has the ordinary ERC-20 transaction-ordering caveat: a spender
may spend an old approval before a replacement is mined. Wallets can revoke and confirm before
granting a replacement. These semantics are unchanged from the vendored ERC-20.

## Delivered tests

| Suite | Evidence |
| --- | --- |
| `test/LaunchToken.t.sol` | Metadata, constructor mint/event, exact transfer accounting/events, full/zero/self transfers, no callbacks, address checks, approval replacement/revocation/isolation, finite/infinite allowance handling, unauthorized/over-balance/over-allowance failures and rollback, missing admin selectors, native-value rejection, runtime size/escape-opcode check, fuzzed conservation and failures |
| `test/LaunchAllocation.t.sol` | Actual token construction by a test factory, whole supply before distribution, modeled 80/10/10 allocation, no launch reserve allocation, later exact 80 million reserve transfer, no vesting, unauthorized spending and insufficient-balance repeat failure |
| `test/LaunchToken.invariant.t.sol` | Stateful sequences of transfers, approvals and delegated transfers among four actors; independent expected balances/allowances and fixed-supply conservation checked after each call |

Foundry configuration uses 1,024 runs per fuzz test and 256 invariant runs at depth 64, with
handler reverts treated as failures. Run with the assignment's seed:
`0x8ebd156f533433c4001d35a08058c8e944c7d8b3e1cdd6e7117e5be075fd1db4`.
Each test initializes its own state and uses no environment reads/writes, forks, shared files,
or live contracts. Test recipient addresses are local fixtures, not deployment addresses.

Local validation passed: `forge build`, `forge fmt --check`, dependency SHA-256 verification,
and all 35 tests with the seed above (0 failures, 0 skips). The four fuzz tests each completed
1,024 runs; the invariant completed 16,384 calls with 0 reverts. The compiled token has a
1,784-byte runtime, 2,712-byte creation code, no library link references, and exactly the nine
standard ERC-20 public functions. The compiler reports `0.8.26+commit.8a97fa7a`.

The supplied protected checks were read as the deployment baseline. The local suite exercises
the token properties without the verifier's environment-based deployment harness. The allocation
model only demonstrates that the token supports the required flow; it neither models swaps nor
validates the real factory's fee splitting, price calculation, LP custody or Merkle proofs.

## External responsibilities and assumptions

- IMD selects the canonical factory and authenticated Robinhood Chain configuration; the token
  does not embed a factory address or restrict its deployment to one chain.
- The factory, its protocol custody/guard/distributor and fee claim implementation are supplied
  by IMD. Source and behavior of those components are outside this token deliverable.
- The requester controls its named paying wallet, completes the separate post-launch transfer
  after verification, and preserves its claim and transfer receipts. The reserve wallet's
  custody and later use are outside the token's control.
- The launch operator checks chain and canonical IMD identity, exact allocation events, pool
  parameters, requester fee entitlement, runtime/source match, and explorer verification.
- Chain liveness, sequencing and finality affect wallet execution independently of token logic.
  The token contains no bridge or L2-specific timing assumptions.

Local testing and source review are not an independent security audit. Slither, Mythril,
live-chain integration tests, factory deployment and explorer verification were not run in
this source task. IMD's independent review and verified deployment remain release steps.
