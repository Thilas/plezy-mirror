# Plezy Mirror

Mirror of plezy releases with standalone `.apk` files

## Install via GitHub Store

1. Install [GitHub Store](https://github.com/OpenHub-Store/GitHub-Store)
2. Search for `plezy-mirror`
3. Install the latest version
4. Done — GitHub Store will auto-update Plezy for you

## Direct Download

Head to the [Releases](https://github.com/Thilas/plezy-mirror/releases/latest) page and grab the APK for your architecture.

| File                            | Architecture | Devices                      |
|---------------------------------|--------------|------------------------------|
| `plezy-android-arm64-v8a.apk`   | ARM 64-bit   | Most modern phones & tablets |
| `plezy-android-armeabi-v7a.apk` | ARM 32-bit   | Older Android devices        |
| `plezy-android-x86_64.apk`      | x86_64       | Emulators, ChromeOS          |

## Why?

Since Plezy v1.13.0, Android builds are released as `.tar.gz` archives. This breaks GitHub Store auto-updates and makes manual installation inconvenient. This repository automatically extracts the APKs daily and publishes them as proper GitHub release assets.

## How it works

A GitHub Action runs daily and on-demand:

1. Checks [Plezy releases](https://github.com/edde746/plezy/releases)
2. Skips versions that are already published here
3. Downloads all `*.apk` files and Android `.tar.gz` archives
4. Extracts the `.apk` files from `.tar.gz` archives
5. Creates a new release with standalone APKs + upstream changelog
