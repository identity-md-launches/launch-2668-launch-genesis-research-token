# Vendored dependencies

- `openzeppelin-contracts` v5.0.2: [OpenZeppelin/openzeppelin-contracts](https://codeload.github.com/OpenZeppelin/openzeppelin-contracts/tar.gz/refs/tags/v5.0.2); archive SHA-256 `18c7b7e949b9a82dcd8cd394426c9c2636dfc263aa2317d4749dbfa0c7b3925a`; 6 files.
- `forge-std` v1.9.7: [foundry-rs/forge-std](https://codeload.github.com/foundry-rs/forge-std/tar.gz/refs/tags/v1.9.7); archive SHA-256 `45157353ab49eab01d294565866731e599b32401757229689ee459aa26b7ee94`; 30 files.

OpenZeppelin contains only the unmodified ERC-20 dependency closure and its MIT license.
forge-std contains its unmodified src directory and both licenses; it is used only by tests.
These are ordinary files, not submodules. Builds and tests need no dependency download.

Verify the vendored files with `sha256sum -c dependencies.sha256`.
The pinned Solidity compiler and Foundry are toolchain prerequisites, not vendored binaries.
