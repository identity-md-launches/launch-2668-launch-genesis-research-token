# GENS test coverage and launch handoff

This suite tests the supplied `src/LaunchToken.sol` and its vendored ERC-20 implementation.
Every helper under `test/` is an offline fixture. No production source, deployment parameter,
dependency, or Foundry configuration is changed by this test contribution.

Run from the repository root:

```sh
forge build
FOUNDRY_FUZZ_SEED=0x8ebd156f533433c4001d35a08058c8e944c7d8b3e1cdd6e7117e5be075fd1db4 forge test
```

The fuzz tests pin 1,024 runs in their source. The invariant pins 256 sequences of 128 handler
calls, with unexpected handler reverts failing the run. Dependencies are already vendored;
the submitted tests use no fork, FFI, network, environment mutation, or scratch-file imports.
Compiler artifacts and logs can optionally be redirected into `test/scratch/` using
`FOUNDRY_OUT=test/scratch/out FOUNDRY_CACHE_PATH=test/scratch/cache`.

## What the suites establish

| Suite | Checks |
| --- | --- |
| `LaunchToken.t.sol` | Fixed supply and metadata, exact accounting and events, zero/full/self transfers, rejecting recipients, approvals, unauthorized and invalid transfers, missing admin functions with correctly encoded calldata, native currency rejection and runtime restrictions |
| `LaunchToken.adversarial.t.sol` | CREATE2 constructor caller versus transaction origin, exactly one mint event, caller impersonation attempts, all sender/spender/recipient alias cases, maximum finite versus infinite approvals, revoke/retry/replacement sequences, truncated calldata, native value on every public ERC-20 function, transfer splitting without tax or dust |
| `LaunchAllocation.t.sol` | Token compatibility with the modeled 80/10/10 distribution, separate requester reserve transfer, immediate spending, unauthorized/repeated/underfunded reserve transfers and approval isolation |
| `LaunchToken.invariant.t.sol` | Random successful and rejected transfers, approval replacement/revocation, finite and infinite delegated spending, exact round trips, and independent balance/allowance conservation after each handler call |

The earlier `docs/REVIEW.md` records the original 35-test run. It describes the earlier suite;
the current test output and source settings describe this expanded contribution.

Local verification with the seed above passed `forge build` and all 53 tests: zero failures
and zero skips, ten fuzz properties at 1,024 runs each, and 32,768 invariant handler calls.
All ten targeted handler actions were exercised, with no unexpected reverts or discarded
calls. Formatting and whitespace checks also passed. No reproducible production defect was
identified in the supplied implementation; this is bounded test evidence, not a live-launch
or independent-audit certification.

## Property selection

The five supplied Pashov discovery perspectives were applied locally; no helper agents were
used. The Trail of Bits guidance informed input generation, failure classification and the
review for vacuous properties. These are original tests, not copied harness templates.

| Review perspective | Property and inputs | Source basis |
| --- | --- | --- |
| Conservation | Total supply stays at `10^27`; every tracked balance equals the independent ledger and the sum is the supply, even after rejected operations | `src/LaunchToken.sol:11`; ERC20 `_update`, lines 188–221 |
| State transitions | A failed delegated transfer cannot consume approval; replacement overwrites, revocation prevents later spending, and successful finite spending consumes only its authorization | ERC20 `transferFrom`, line 154; `_approve`, line 284; `_spendAllowance`, line 305 |
| Round trips and rounding | Send and return zero, one wei, an arbitrary amount or the full balance: exact restoration. Two partial transfers equal their total with no fee or dust | Plain-transfer requirement; ERC20 `_update`, line 188 |
| Adversarial value extraction | No over-balance or over-allowance spend, no origin or appended-address impersonation, no constructor caller privilege after launch; probe maximum uint256 and downstream failure after allowance validation | ERC20 `transfer`, line 109, `transferFrom`, line 154; Context `_msgSender`, line 17; no added external methods in LaunchToken |
| Token-specific behavior | Full/zero/self transfers, all five address-alias partitions, invalid zero recipient/spender, infinite allowance exception, nonpayable ABI and constructor-only mint | ERC20 `_transfer`, line 171; `_approve`, line 284; `_spendAllowance`, line 305; fixed plain ERC-20 brief |

These are required properties of the requested plain token or exact accounting identities.
No vault, AMM pricing, fee-rounding, vesting, staking or reward invariant is inferred from
interfaces absent from the repository.

The handler maintains expected balances and allowances from inputs and successful actions,
without reading token state back into those expectations. Its closed actor set owns the
whole supply. `approveAndSpend` chooses a funded actor and a positive amount so random
sequences reach real delegated transfers. Deliberate failure handlers check the exact error;
their subsequent invariant check requires the pre-failure balances and allowances to remain.
`roundTrip` checks the intermediate balance as well as restoration, so a no-op transfer cannot
pass it. Explicit selectors restrict the invariant target to these actions. The runner's call
table exposes which actions were exercised. No generated input is discarded with `vm.assume`.

## Deployment and claims boundary

Use the existing [deployment/source publication guide](../docs/DEPLOYMENT.md) and
[claim guide](../docs/CLAIMS.md) with the authenticated launch handoff. Required economics:

- Robinhood Chain `4663`, GENS paired with canonical Robinhood IMD through the standard factory.
- Exactly 1,000,000,000 GENS at 18 decimals: 800,000,000 to seeded liquidity, 100,000,000 to
  protocol Swarm custody, and 100,000,000 to requester `0x550011cadcc758969391050241b2fc43ed1a4b97`.
- After verified launch, that requester separately calls GENS `transfer` to
  `0x4a532cbc877fbbd4950fdab65bfea2e8567b857b` for `80000000000000000000000000` minor units,
  with zero native value. With no other movements this leaves 20,000,000 GENS. Neither
  wallet allocation has vesting. The factory does not perform the reserve transfer.
- Standard total pool fee 1.25%, with 80% of the seeded position's collected fees retained
  by the requester and 20% assigned to the network. No splitter, reserve deduction, or extra
  hook swap fee. Ordinary token transfers do not carry a tax or change fee beneficiaries.

The local allocation model proves only that GENS supports this token flow. The actual factory,
canonical IMD deployment, pool/guard, LP custody and fee policy, fee claims, and Swarm Merkle
claims are not implemented here and cannot be certified by this suite. No fork block or RPC
was supplied. Live integration validation remains owed against authenticated deployed contracts,
including actual allocations, exact pool key, 1.25% fee, 80/20 fee beneficiaries, and valid,
invalid and duplicate claims. Do not infer successful live claims from these token tests.

The production source and vendored dependencies are already in the repository. Explorer source
verification/publication remains a deployment action using the actual GENS address and exact
compiler input described in the existing guide; this test task neither broadcasts nor claims
that verification has occurred. No Ethereum GenesisResearch contract or archive is modified.
GENS-funded expedition checkout is not implemented and is not live.
