fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios adhoc

```sh
[bundle exec] fastlane ios adhoc
```

构建一个正式环境版本上传至pgyer

### ios match_dev

```sh
[bundle exec] fastlane ios match_dev
```

Match dev

### ios match_prod

```sh
[bundle exec] fastlane ios match_prod
```

Match prod

### ios match_nuke_dev

```sh
[bundle exec] fastlane ios match_nuke_dev
```

Match nuke dev

### ios match_nuke_appstore

```sh
[bundle exec] fastlane ios match_nuke_appstore
```

Match nuke appstore

### ios match_appstore

```sh
[bundle exec] fastlane ios match_appstore
```

Match appstore

### ios match_adhoc

```sh
[bundle exec] fastlane ios match_adhoc
```

Match adhoc

### ios setup_match_appstore

```sh
[bundle exec] fastlane ios setup_match_appstore
```

match setup appstore

### ios ci_release

```sh
[bundle exec] fastlane ios ci_release
```

build

### ios release

```sh
[bundle exec] fastlane ios release
```

build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
