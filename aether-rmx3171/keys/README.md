# Private AVB keys

Production AVB private keys live here locally but must never be committed.

Generate keys with:

```bash
scripts/release/generate_avb_keys.sh aether-rmx3171/keys
```

Build/sign with:

```bash
export AETHER_AVB_KEY_PATH="$PWD/aether-rmx3171/keys/aether_avb_key.pem"
```

`.gitignore` already excludes `*.pem` and `*.priv` in this directory.
Commit only public metadata if you intentionally need it.
