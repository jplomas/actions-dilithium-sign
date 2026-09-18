# actions-dilithium-sign

GitHub Action to generate Dilithium post-quantum signatures for files.

## Usage

```yaml
- uses: theQRL/actions-dilithium-sign@v2
  with:
    patterns: |
      dist/*.zip
      dist/*.tar.gz
    hexseed: ${{ secrets.DILITHIUM_HEXSEED }}
    output: signatures.txt
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `hexseed` | Dilithium hexseed for signing | Yes | - |
| `patterns` | Glob patterns for files to sign (one per line) | Yes | - |
| `output` | Output file path for signatures | No | `signatures.txt` |

## Outputs

The action generates a signatures file containing one line per signed file:

```
filename1.zip 3b4e5f...signature_hex...
filename2.tar.gz 7a8b9c...signature_hex...
```

## Example: Sign release artifacts

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: make build

      - name: Sign artifacts
        uses: theQRL/actions-dilithium-sign@v2
        with:
          patterns: |
            dist/*.zip
          hexseed: ${{ secrets.DILITHIUM_HEXSEED }}
          output: signatures.txt

      - name: Upload signatures to release
        uses: softprops/action-gh-release@v1
        with:
          files: signatures.txt
```

## Generating a hexseed

Use [qrlft](https://github.com/theQRL/qrlft) to generate a new Dilithium keypair:

```bash
qrlft new -a dilithium mykey
```

This creates:
- `mykey` - Private key (PEM format)
- `mykey.pub` - Public key (PEM format)
- `mykey.private.hexseed` - Hexseed for use with this action

Store the hexseed as a GitHub secret (`DILITHIUM_HEXSEED`).

## Verifying signatures

Use qrlft to verify signatures:

```bash
qrlft verify -a dilithium --signature=<sig_hex> --publickey=<pk_hex> file.zip
```

## Which qrlft signs

The image builds qrlft at the commit `QRLFT_COMMIT` pins in the `Dockerfile`,
currently v4.0.0. The clone used to be unpinned, which meant a rebuild tracked
whatever qrlft's main branch had become. That is not a theoretical problem:
qrlft has since made `--algorithm` mandatory, so an unpinned rebuild would have
produced an image whose own entrypoint no longer ran.

This action is deprecated, and its job is to keep behaving exactly as it always
has. Moving the pin is a deliberate act with a release behind it, not something
a rebuild should do on its own.

`./test/run.sh` signs a fixture release with the pinned qrlft and checks the two
still agree, that the output is Dilithium5 rather than something of a different
length, and that altered bytes are rejected. It builds the pinned commit, so it
needs Go; set `QRLFT` to use an existing binary. CI runs it on every push.

## License

MIT
