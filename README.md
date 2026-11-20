# TypeBlend

TypeBlend is a Vietnamese–English Telex input method for Apple Silicon Macs. It lets you type both languages in the same sentence. When a sequence such as `gif` could mean either the English file format or the Vietnamese word *gì*, TypeBlend uses nearby words to choose a spelling. All typing and scoring stay on your Mac.

## Install or update

On an Apple Silicon Mac running macOS 13 or later, open the [latest TypeBlend.pkg](https://github.com/sonmai/TypeBlend/releases/latest/download/TypeBlend.pkg) and install it for your user account. This link becomes active with the first notarized release. The installer upgrades the existing `~/Library/Input Methods/TypeBlend.app` in place. Sign out and back in to load the new build. On first install, add TypeBlend under System Settings → Keyboard → Input Sources → Vietnamese.

## Release

Push a semantic version tag on the tested commit, for example:

```sh
git tag v0.2.7
git push origin v0.2.7
```

GitHub Actions uses the tag as the installer and application version. It runs the tests, exercises a user-local upgrade, signs the application and installer, submits the installer to Apple, staples and verifies the ticket, then publishes `TypeBlend.pkg` to GitHub Releases.

Configure these repository secrets once:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded, password-protected PKCS#12 export containing the Developer ID Application and Developer ID Installer certificates and their private keys |
| `DEVELOPER_ID_P12_PASSWORD` | Password for that export |
| `NOTARY_KEY_BASE64` | Base64-encoded App Store Connect team API private key for notarization |
| `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID` | Key ID and issuer ID for the same team key |

If credentials are missing, configure them under Settings → Secrets and variables → Actions and rerun the failed release job for the same tag. For a local packaging test, run `./Packaging/package.sh 0.2.7`. Without signing identities it produces a development installer in `build/TypeBlend.pkg`.

## Architecture

### System overview

TypeBlend runs as a macOS input source. Applications such as Notes and Word communicate with it through InputMethodKit. The app bundles the Telex engine and the model data it needs for typing.

### Components inside TypeBlend.app

Each arrow points from a component to a dependency it uses.

```mermaid
flowchart TB
    mac["macOS InputMethodKit"]
    subgraph bundle["TypeBlend.app"]
        adapter["App · TypeBlendController"]
        subgraph core["TypeBlend core"]
            session["Session · composition state"]
            ranker["Ranker · spelling selection"]
        end
        telex["TelexCore · upstream VietTelex engine"]
        assets["Resources · bundled model data"]
    end
    adapter -->|integrates with| mac
    adapter -->|owns| session
    session -->|obtains Telex spelling from| telex
    session -->|delegates spelling selection to| ranker
    ranker -->|loads| assets
```

`TypeBlendController` inserts ordinary text in Apple Notes and the ChatGPT desktop app so that the current word has no composition underline. Before revising a spelling, it checks that the caret and previously inserted text still match. Other editors use the InputMethodKit marked-text path. `Session` tracks the original keystrokes, the word being composed, nearby words and manual corrections. The replay tests exercise this same session logic one keystroke at a time. [macOS integration](App/main.swift) · [Session state](Core/Session.swift) · [Replay tests](Tests/main.swift)

### Spelling selection and model data

The ranker receives the raw keystrokes, the Telex spelling and the available context. The default build uses the following resources.

| Component | Bundled data | Responsibility |
|---|---|---|
| Supported spelling pairs | `collisions.txt` and entries in `model.json` | Identify keystroke sequences eligible for contextual scoring. |
| N-gram scorer | `ng.bin`, `ng-tags.bin` | Look up scores for nearby word combinations and verify the lookup tags. Use the Telex engine’s default spelling when the evidence is weak. |
| SeedRanker | `model.json` | Score the two pairs `gif/gì` and `max/mã` with a dedicated model. |

The Python tools generate model data offline. XLM-R is used during experimental training. The shipping input method uses the bundled resources listed above. [Ranker](Core/Context.swift) · [SeedRanker](Core/Ranker.swift) · [Training](Tools/fit_context.py) · [Build script](build.sh)

## Build and test

On an Apple Silicon Mac with Xcode Command Line Tools installed, run these commands from the repository root.

```sh
./test.sh
./build.sh
```

The build produces an ad hoc signed app at `build/TypeBlend.app`. To include the updater and input-source activation helper in the same directory, run:

```sh
cp Packaging/Update.command build/
clang -mmacosx-version-min=13.0 -framework Carbon Packaging/activate.c -o build/activate
```

## Updating the VietTelex engine

The Swift sources in `TelexCore/` come from VietTelex commit `b9cf90de6df42438b80b5e3d7d2c00669c1bf1de`. When updating the engine, compare the upstream sources with the local copy, review the attribution notices and rerun the tests. TypeBlend’s contextual spelling logic lives in `Core/`. [Pinned upstream sources](https://github.com/ptrinh/VietTelex/tree/b9cf90de6df42438b80b5e3d7d2c00669c1bf1de/TelexCore/Sources/TelexCore) · [Engine license](TelexCore/LICENSE) · [Data sources](TelexCore/DATA-SOURCES.md) · [Third-party notices](Notices/)

To retrain the experimental models, the scripts in `Tools/` expect Universal Dependencies r2.15 data in `../data` and an XLM-R checkpoint in `../xlmr`. Building the input method uses the model files already in the repository.

## License

TypeBlend's original code is licensed under the [MIT License](LICENSE). The bundled VietTelex engine includes its [upstream MIT license](TelexCore/LICENSE) and [data attributions](TelexCore/DATA-SOURCES.md). The model tables `ng.bin` and `student.bin` are distributed under CC BY-SA 4.0. See the [third-party notices](Notices/SOURCES.txt) for details.
