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

## Sui RPC fixtures (recorded 2026-05-18)

**Test wallet:** `0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8`
— resolved from the SuiNS name `validator.sui` (reverse-resolves to `doonie.sui`).
Picked because the wallet exposes the full diversity we want to decode against:
19 token balances (including SUI), 1 active delegated stake position, several
NFTs in its owned-objects page (incl. SuiNS registrations), and a working
forward + reverse SuiNS resolution.

**Source endpoint:** `https://fullnode.mainnet.sui.io:443`

**Recorded methods:**
- `sui-getAllBalances-success.json` — `suix_getAllBalances` for the wallet
- `sui-getCoinMetadata-sui.json` — `suix_getCoinMetadata` for `0x2::sui::SUI`
- `sui-getOwnedObjects-page1.json` — first page (limit 10) of `suix_getOwnedObjects` for the wallet
- `sui-getStakes-success.json` — `suix_getStakes` for the wallet
- `sui-getLatestSuiSystemState-truncated.json` — `suix_getLatestSuiSystemState`, validator list truncated to 5 entries to keep the fixture small (~13 KB vs ~240 KB raw)
- `sui-resolveNameServiceAddress-success.json` — `suix_resolveNameServiceAddress` for `validator.sui`
- `sui-resolveNameServiceNames-success.json` — `suix_resolveNameServiceNames` for the wallet

**Recording commands (executed verbatim):**

```bash
WALLET="0xe6d2886da571e044dd3873d40eba75aa5610c51618f0c48fa0ca376d492d56a8"
NODE="https://fullnode.mainnet.sui.io:443"
FIX_DIR="Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_getAllBalances\",\"params\":[\"$WALLET\"]}" \
  > "$FIX_DIR/sui-getAllBalances-success.json"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_getCoinMetadata","params":["0x2::sui::SUI"]}' \
  > "$FIX_DIR/sui-getCoinMetadata-sui.json"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_getOwnedObjects\",\"params\":[\"$WALLET\",{\"filter\":null,\"options\":{\"showType\":true,\"showDisplay\":true,\"showContent\":false}},null,10]}" \
  > "$FIX_DIR/sui-getOwnedObjects-page1.json"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_getStakes\",\"params\":[\"$WALLET\"]}" \
  > "$FIX_DIR/sui-getStakes-success.json"

# System state response is ~240 KB raw; capture then truncate activeValidators to 5.
curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_getLatestSuiSystemState","params":[]}' \
  > "$FIX_DIR/sui-getLatestSuiSystemState-raw.json"
python3 - "$FIX_DIR/sui-getLatestSuiSystemState-raw.json" "$FIX_DIR/sui-getLatestSuiSystemState-truncated.json" <<'PY'
import json, sys
raw = json.load(open(sys.argv[1]))
result = raw.get("result", {})
result["activeValidators"] = result.get("activeValidators", [])[:5]
out = {"jsonrpc": "2.0", "id": 1, "result": result}
json.dump(out, open(sys.argv[2], "w"), indent=2)
PY
rm "$FIX_DIR/sui-getLatestSuiSystemState-raw.json"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"suix_resolveNameServiceAddress","params":["validator.sui"]}' \
  > "$FIX_DIR/sui-resolveNameServiceAddress-success.json"

curl -s -X POST "$NODE" -H 'content-type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"suix_resolveNameServiceNames\",\"params\":[\"$WALLET\"]}" \
  > "$FIX_DIR/sui-resolveNameServiceNames-success.json"
```

## CoinGecko fixtures (recorded 2026-05-18)

- `coingecko-coins-list-sui-platform.json` — `/coins/list?include_platform=true` filtered down to entries where `platforms.sui` is set (kept 165 entries from the ~17.4k full list)
- `coingecko-coins-markets-multi.json` — `/coins/markets?vs_currency=usd&ids=sui,usd-coin,tether` (3 entries: tether, usd-coin, sui)

**Recording commands (executed verbatim):**

```bash
FIX_DIR="Packages/SuiWidgetKit/Tests/SuiWidgetKitTests/Fixtures"

# Coin list — large response (~2.6 MB). Filter down to Sui-platform entries only.
curl -s 'https://api.coingecko.com/api/v3/coins/list?include_platform=true' \
  > "$FIX_DIR/coingecko-coins-list-raw.json"
python3 - "$FIX_DIR/coingecko-coins-list-raw.json" "$FIX_DIR/coingecko-coins-list-sui-platform.json" <<'PY'
import json, sys
raw = json.load(open(sys.argv[1]))
filtered = [c for c in raw if isinstance(c.get("platforms"), dict) and c["platforms"].get("sui")]
json.dump(filtered, open(sys.argv[2], "w"), indent=2)
PY
rm "$FIX_DIR/coingecko-coins-list-raw.json"

# Multi-coin market snapshot.
curl -s 'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=sui,usd-coin,tether' \
  > "$FIX_DIR/coingecko-coins-markets-multi.json"
```

