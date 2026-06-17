# AppworkCache

LRU + TTL cache exercise for AppWork. Wraps a slow upstream service with a
concurrent `fetch/1` interface.

## Requirements

- Elixir ~> 1.18
- Erlang/OTP 27+

## Running tests

```bash
mix test
```

## Version progress

| Version | Status  | Description                          |
|---------|---------|--------------------------------------|
| V0      | In progress | Cache and upstream interfaces    |
| V1      | Pending | Basic capped cache (FIFO)            |
| V2      | Pending | LRU eviction on distinct keys        |
| V3      | Pending | LRU + TTL expiration                 |
| V4      | Pending | Near real-time O(1) fetch (optional) |

Architecture notes: [docs/architecture.md](docs/architecture.md)
