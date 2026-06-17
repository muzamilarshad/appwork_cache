# Architecture

V0 defines the cache and upstream interfaces. Storage and eviction arrive in V1+.

## Data flow (V0)

```mermaid
flowchart LR
  Client -->|"fetch(req)"| CacheBehaviour
  CacheBehaviour -->|"miss only V1+"| UpstreamBehaviour
  UpstreamBehaviour --> SlowUpstreamGenServer
  CacheBehaviour -.->|"V1+ storage"| CacheStore
```

## Module diagram (V0)

```mermaid
classDiagram
  class CacheBehaviour {
    <<behaviour>>
    +fetch(request) Response
  }
  class UpstreamBehaviour {
    <<behaviour>>
    +fetch(request) Response
  }
  class Request {
    +id: String.t()
    +hash(request) integer
  }
  class Response {
    +body: term()
  }
  class SlowUpstream {
    +fetch(request) Response
    +call_count() integer
  }
  CacheBehaviour ..> UpstreamBehaviour : wraps on miss V1+
  CacheBehaviour ..> Request
  CacheBehaviour ..> Response
  UpstreamBehaviour ..> Request
  UpstreamBehaviour ..> Response
  SlowUpstream ..|> UpstreamBehaviour
```

`call_count` on `SlowUpstream` is test-only: it tracks how many times the fake
upstream was called so tests can prove cache hits avoid upstream fetches.

## How to read the diagram

- **CacheBehaviour** — contract for the cache (`fetch/1`). Implemented in V1.
- **UpstreamBehaviour** — contract for the slow backend (`fetch/1`).
- **SlowUpstream** — test GenServer that sleeps and counts calls (not production).
- **Request / Response** — structs passed through both interfaces.
- Dashed **wraps on miss V1+** — cache consults upstream only when it has no valid entry.
