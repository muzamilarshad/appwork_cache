# AppworkCache

LRU + TTL cache exercise for AppWork. Wraps a slow upstream service with a
concurrent `fetch/1` interface returning `{:ok, response}` or `{:error, term}`.

## Requirements

- Elixir ~> 1.18
- Erlang/OTP 27+

## Running tests

```bash
mix test
```

## Manual testing (IEx)

`iex -S mix` starts `UserStore` and `Cache.Server` under the app supervisor.
Calling `stop/1` kills them, but the supervisor restarts them immediately — so
`start_link` fails with `{:already_started, pid}`.

Use `--no-start` for manual control (`cap: 2`, fresh counters):

```bash
iex -S mix run --no-start
```

```elixir
alias AppworkCache.Request
alias AppworkCache.Cache.Server
alias AppworkCache.Upstreams.UserStore

req1 = %Request{id: "users/1"}   # ttl_seconds: 1
req2 = %Request{id: "users/2"}   # ttl_seconds: 300
req3 = %Request{id: "users/3"}
unknown = %Request{id: "users/999"}

{:ok, _} = UserStore.start_link(sleep_ms: 0)
{:ok, _} = Server.start_link(cap: 2, upstream: UserStore)
```

Restart between scenarios: `UserStore.stop(); Server.stop()`, then `start_link`
again. Or exit IEx and reopen.

**Cache hit** — second fetch for the same key should not call upstream:

```elixir
Server.fetch(req2)
Server.fetch(req2)
UserStore.call_count()  # => 1
```

**TTL** — `users/1` expires after 1s; fetch back-to-back for a hit, or wait
`>1s` for a miss. Pauses while typing in IEx count as expiry.

```elixir
Server.fetch(req1)
Server.fetch(req1); UserStore.call_count()  # => 1
:timer.sleep(1_100)
Server.fetch(req1); UserStore.call_count()  # => 2
Server.fetch(req1); UserStore.call_count()  # => 2 (immediate hit)
```

**LRU** (`cap: 2`) — promote on hit; evict least-recently-used distinct key:

```elixir
Server.fetch(req1); Server.fetch(req2)
Server.fetch(req1)   # promotes users/1
Server.fetch(req3)   # evicts users/2, not users/1
Server.fetch(req2)   # miss (evicted)
Server.fetch(req1)   # hit
```

**Errors not cached** — upstream is consulted each time; only successful
lookups increment `call_count`:

```elixir
Server.fetch(unknown)  # {:error, :not_found}
Server.fetch(unknown)
UserStore.request_count()  # => 2
UserStore.call_count()     # => 0
```

## Version progress

| Version | Status  | Description                          |
|---------|---------|--------------------------------------|
| V0      | Done    | Cache and upstream interfaces        |
| V1      | Done    | Basic capped cache (FIFO) + ETS      |
| V2      | Done    | LRU eviction on distinct keys        |
| V3      | Done    | LRU + TTL expiration                 |
| V4      | Pending | Near real-time O(1) fetch (optional) |

Architecture notes: [docs/architecture.md](docs/architecture.md)

## V0 (complete)

- `AppworkCache.Cache` — cache behaviour (`fetch/1`, `child_spec/1`)
- `AppworkCache.Upstream` — upstream behaviour (`fetch/1`)
- `AppworkCache.Request` — `%Request{id: ...}` with `hash/1`
- `AppworkCache.Response` — `%Response{body: ..., ttl_seconds: ...}` with `ttl/1`

## V1 (complete)

- `AppworkCache.Cache.Server` — capped cache with ETS-backed concurrent reads
- `AppworkCache.Upstreams.UserStore` — simulated slow user DB (ETS, seeds `users/1`–`users/10`)
- FIFO eviction (replaced by LRU in V2)

## V2 (complete)

- `AppworkCache.Cache.LRU` — pure LRU queue helpers (`touch/2`, `insert/3`)
- `Cache.Server` promotes on cache hit via `GenServer.call({:touch, hash})`
- LRU eviction of distinct keys when capacity exceeded

## V3 (complete)

- `AppworkCache.Cache.Entry` — `%Entry{response, expires_at}` stored in cache ETS
- `Response.ttl/1` drives expiration; `UserStore` returns per-user `ttl_seconds`
- Expired entries lazily invalidated on fetch (no background sweeper)
- Errors (`{:error, :not_found}`) are not cached
