# Test Fixtures

This directory holds raw API responses recorded once during Phase 1 plan execution
and committed to git. Tests replay them via `MockURLProtocol`; no live network is
issued during `swift test`.

Future tasks (7, 8, 9) record:
- Sui RPC method responses for a chosen public mainnet wallet (Task 7)
- CoinGecko `/coins/list?include_platform=true` + `/coins/markets` (Task 8)
- Sui blog RSS + MystenLabs releases Atom (Task 9)
- A small representative PNG for the image pipeline (Task 11)

The chosen wallet address and the curl commands used will be added below as each
recording lands.
