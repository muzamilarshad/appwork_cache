import Config

config :appwork_cache, cap: 100

import_config "#{config_env()}.exs"
