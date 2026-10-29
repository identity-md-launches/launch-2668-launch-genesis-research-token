# Deployment and source publication

This is the source handoff to IMD's standard ProjectFactory launch process, not a standalone
wallet deployment. The factory must be the token's constructor caller so it can validate and
distribute the entire supply. There is no contributor broadcast script and no application
initialization transaction. `launch.json` belongs to the subsequent manifest step and is not
part of this source deliverable.

## Parameters for the manifest and deployer

| Parameter | Required value |
| --- | --- |
| Kind | `evm_project` |
| Chain | Robinhood Chain, `4663` |
| Launch token | `src/LaunchToken.sol:LaunchToken` |
| Token name / symbol | `Genesis Research Token` / `GENS` |
| Constructor arguments | None |
| Decimals | `18` |
| Supply in minor units | `1000000000000000000000000000` |
| Application contracts | Empty list (`[]`) |
| Requester / paying wallet / `$owner` | `0x550011cadcc758969391050241b2fc43ed1a4b97` |
| Pool allocation | 80% of fixed supply; `800000000000000000000000000` minor units |
| Swarm allocation | 10%; `100000000000000000000000000` minor units; factory-supplied MerkleDistributor |
| Requester wallet allocation | Remaining 10%; `100000000000000000000000000` minor units |
| `pool.pairedCurrency` | `0x5f7bb59365ce557c26dbcaa4ee9d39a4b95b7127` (canonical Robinhood IMD) |
| `pool.fee` | `12500` (1.25%, not basis points; no dynamic-fee flag) |
| `pool.tickSpacing` | `60` |
| `pool.initialPrice` | `"79228162514264337593543950336"` (legacy manifest value, sqrt price Q96) |
| Policy opening market cap | `2500 IMD` for the entire supply |
| Seeded LP fee beneficiaries | 80% requester, 20% network; no requester deduction |
| Custom hooks or additional swap fees | None |
| Additional allocation or vesting contracts | None |

The deployer derives the effective opening price from the policy market cap and actual token
ordering. The manifest's one-to-one Q96 value is not a promised executed opening price. The
factory seeds with launch tokens only, whichever side of the pair GENS sorts to. Do not send
an equal amount of IMD based on the manifest price. The factory reads its effective fee from
the chain's LaunchFees policy; admission and post-launch checks must confirm 12500.

The standard factory supplies an initialization-only PoolInitializationGuard with no swap
callbacks. It is not a contributor application contract. Record the exact returned `poolKey`,
including currencies, fee, tick spacing and guard address. Do not reconstruct a key with a
guessed hook address. Protocol Swarm distribution comprises 2% of total supply shared among
accepted contributors and 8% shared among paired seats at admission; IMD supplies the root and
proofs. No contributor code or wallet address replaces that distributor.

## Before deployment — IMD release operator

1. Build the accepted sources with the pinned compiler and settings; run the documented tests
   and independent review. Use only `LaunchToken` as the production artifact. All contracts
   under `test/` are local scaffolding.
2. Confirm the authenticated chain configuration and RPC report chain ID 4663. Verify code,
   symbol and 18 decimals for the assignment-pinned IMD address. The address is a supplied
   launch parameter, not a live-chain observation made by this repository.
3. Resolve the standard ProjectFactory, LaunchFees, pool infrastructure and claim ABIs from
   the authenticated IMD deployment configuration. These addresses are intentionally not
   invented or embedded in the token. Confirm the requester and 80/20 seeded-position fee
   entitlement, 80% token seed, 10% Swarm allocation, and 1.25% total pool fee.
4. Generate the manifest, source attestation, salts and Swarm allocation through the standard
   IMD pipeline. The authorized deployer submits the factory transaction. Contributors do
   not require or receive deployment keys.

## Verify the completed launch — IMD release operator and requester

Use the launch receipt and state at its block for allocation checks; subsequent trades,
claims and transfers can change current balances. Verify all of the following:

- The creation artifact and runtime match the accepted source and compiler settings.
  Constructor arguments are empty, the name/symbol and 18 decimals match, and total supply is
  exactly `1000000000000000000000000000`.
- Minting assigned the whole supply to the actual ProjectFactory. Factory accounting and
  events show 800,000,000 GENS seeded, 100,000,000 delivered to its Swarm distributor, and
  100,000,000 delivered to the requester. The reserve received no factory allocation.
- The exact pool key pairs this GENS address with canonical IMD, uses fee 12500 and tick
  spacing 60, and uses the protocol's initialization guard with no extra swap fee.
- The seeded LP position's fee record names the requester above for its complete 80% share;
  the network has the other 20%. No fee splitter or reserve fee recipient is inserted.
- The handoff contains the launch transaction/block, token address, factory address, pool
  key/ID, position ID and custody record, claim contract addresses and verified ABIs, Swarm
  distributor/root/proof source, and token explorer source-verification link.

The token does not enforce correct factory configuration or the requester's subsequent wallet
action. These verification steps are operational responsibilities, not features added to GENS.

## Publish and verify sources

Publish this source tree with its MIT license, the exact vendored OpenZeppelin sources and
license, `foundry.toml`, `remappings.txt`, and dependency hashes. The full source is supplied
here so the verifier needs no downloads. Preserve the accepted source revision and compiler
artifacts in the launch handoff.

Explorer verification is performed by IMD after the actual deployment address exists. Set
`GENS_TOKEN` to that address from the verified handoff; do not substitute the requester, IMD,
reserve, or a test token. Generate the compiler input without broadcasting:

```sh
forge verify-contract --chain 4663 --compiler-version 0.8.26 \
  --show-standard-json-input "$GENS_TOKEN" src/LaunchToken.sol:LaunchToken \
  > GENS-standard-input.json
```

Submit that standard JSON and the real address to the chain's authenticated explorer source
verification service, or use its configured Foundry verifier integration. Select Solidity
0.8.26, optimizer 200 runs, Paris EVM, no IR pipeline, metadata hash `none`, MIT license, and
empty constructor arguments. Keep the source paths and remappings from this build. Verification
requires the token's creation/runtime bytecode to match; a successful local test is not explorer
verification. Publish the resulting verification link with the launch receipt before labeling
the launch verified or requesting the separate reserve transfer.
