# Cache debbuging 

To make the process of configuration and debugging more comfortable, we provide several useful ENV variables.

| Variable  | Purpose |
| ---       | ---        |
| `GEKO_CONFIG_STATS_OUTPUT` | Saves geko command logs to the `.geko` folder in the project root. |
| `GEKO_CONFIG_CACHE_TARGET_HASHES_SAVE` | During cache warmup, it saves logs for each module |
| `GEKO_CONFIG_LOG_STORAGE_DIR` | Allows you to specify a custom folder for build, hash, and analytics logs. If not specified, it saves to the `geko` folder in the project root. |