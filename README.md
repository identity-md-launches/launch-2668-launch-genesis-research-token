# Genesis Research Token (GENS)

Source release for a token-only IMD project launch on **Robinhood Chain, chain ID 4663**.
The production artifact is [`src/LaunchToken.sol:LaunchToken`](src/LaunchToken.sol).
It has no constructor arguments and mints exactly **1,000,000,000 GENS**, with **18 decimals**,
to its deploying factory. The total supply is `1000000000000000000000000000` minor units.

This repository supplies the token, vendored dependencies, tests, and launch/claim instructions.
The IMD launch pipeline performs attestation, manifest generation, deployment and explorer
verification after acceptance. No live deployment, pool, claim, reserve transfer, or explorer
verification is asserted by this source release.

## Token behavior

`LaunchToken` inherits the unmodified OpenZeppelin v5.0.2 ERC-20 implementation and calls
`_mint` only in its constructor. It exposes standard ERC-20 metadata, balances, allowances,
`approve`, `transfer`, and `transferFrom`. Transfers move exactly the requested amount.
Zero-amount transfers work; zero-address recipients and spenders are rejected. Finite allowances
decrease on spending; an allowance of `uint256.max` follows OpenZeppelin's unlimited-approval
semantics. Failed transfers revert all changes, including allowance consumption.

There is no owner or admin, post-constructor mint or external burn, transfer tax, blacklist,
pause, upgrade, vesting, fee splitter, research-fund fee deduction, or additional hook swap fee.
There are no application contracts. The factory supplies its standard pool and MerkleDistributor.
Neither the factory nor the requester receives token administration powers.

## Allocation and fees

Requester/paying wallet: `0x550011cadcc758969391050241b2fc43ed1a4b97`.
Genesis reserve wallet: `0x4a532cbc877fbbd4950fdab65bfea2e8567b857b`.

| Destination at factory launch | GENS | Fixed supply share |
| --- | ---: | ---: |
| GENS/IMD pool seed | 800,000,000 | 80% |
| Protocol Swarm MerkleDistributor | 100,000,000 | 10% |
| Requester wallet | 100,000,000 | 10% |
| Genesis reserve wallet | 0 | 0% |

**After verified launch**, the requester separately transfers exactly **80,000,000 GENS**
(`80000000000000000000000000` minor units) to the reserve wallet. Assuming no other wallet
movements, that leaves **20,000,000 GENS** (`20000000000000000000000000` minor units) immediately
available to the requester. Both holdings are unvested and freely transferable. The token and
factory do not enforce this later wallet action, earmark reserve funds, or prevent the wallets
from spending their balances. The requester is responsible for completing and recording it.

The pair is canonical Robinhood IMD at `0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127`
(18 decimals), as pinned by the assignment. The standard factory pool fee is **1.25%** (`12500`,
in millionths): **80% of the seeded LP position's collected fees belongs to the requester and
20% to the network**. The requester retains its whole share. No share of these fees is sent to
the reserve, and holding GENS by itself does not confer a fee claim. The split corresponds to
1% / 0.25% of swap input attributable to that position's fee accrual, before protocol rounding;
it is not a guarantee of all pool fees if other liquidity participates, or of any revenue.

## Build and test

Use Foundry with Solidity **0.8.26**, as pinned in [`foundry.toml`](foundry.toml). Dependencies
are ordinary vendored files; no install command, submodule, fork, RPC, wallet key, environment
configuration or network is needed for tests. The compiler itself must already be installed
for an offline build. No FFI or filesystem cheatcode permissions are enabled.

```sh
forge build
FOUNDRY_FUZZ_SEED=0x8ebd156f533433c4001d35a08058c8e944c7d8b3e1cdd6e7117e5be075fd1db4 forge test
forge fmt --check
sha256sum -c dependencies.sha256
```

The tests cover ERC-20 success and failure cases, finite/unlimited approvals, event contents,
atomic failure rollback, unauthorized spending, absent administrative selectors, runtime
restrictions, allocation and reserve-transfer scenarios, and stateful balance/allowance
conservation. The allocation harness is explicitly a local model; no real ProjectFactory,
Uniswap pool, Merkle proof, or fee-claim implementation was supplied or tested here.

Compiler choices: optimizer enabled with 200 runs, `via_ir` disabled, `bytecode_hash = "none"`,
and Paris EVM output for conservative opcode compatibility. Production code has no chain,
timestamp, block-number, oracle, or external-contract dependency. Chain selection and allocation
are the launch pipeline's responsibility.

## After launch

There are **no token configuration setters** or initialization calls. IMD's deployer must
provide the verified token address, exact pool key, seeded position identifier, factory and
claim addresses/ABIs, launch receipt, and source verification link. The requester checks that
handoff, makes its reserve transfer, and can trigger fee collection through the standard
protocol claim interface. Swarm beneficiaries obtain their allocations/proofs from IMD.

Read [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for the exact launch parameters and source
publication procedure, [`docs/CLAIMS.md`](docs/CLAIMS.md) for wallet and claim responsibilities,
and [`docs/REVIEW.md`](docs/REVIEW.md) for validation boundaries. Dependency versions, origins,
licenses, and hashes are recorded in [`DEPENDENCIES.md`](DEPENDENCIES.md).

## Scope

GENS-funded expedition checkout is **not implemented and is not live**. This release includes
no staking rewards, promised yield, fundraising contract, buyback, extra token, website
redeployment, or changes to the existing Ethereum `GenesisResearch` contract or its archives.
