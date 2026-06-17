import Config

# Suppress auto-start of UserStore and Cache.Server so test setups
# can control process lifecycle and options (e.g. sleep_ms, cap) directly.
config :appwork_cache, start_children: false
