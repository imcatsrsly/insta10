# Insta10

An Objective-C UIKit interface prototype designed for iOS 10, with the iPhone 5s (320 × 568 pt) as the first layout target. Its screen structure follows Instagram 10.29 (2016–2017); it uses the original asset catalog for Instagram glyphs and the wordmark. Screens currently show neutral loading skeletons and do not sign in or contact Instagram.

## Interface nodes

- Home feed and post cards
- Explore grid with a Reels shelf controlled by the Options toggle
- Activity list
- Profile and profile grid
- Comments, Reels viewer, Options, and a placeholder node for later features
- Reels shelf toggle in Options
- 4-inch launch image support so iPhone 5/5s use the full screen
- Shared vector icons drawn in the iOS 10 line style

Each screen is a separate `IGNodeController` subclass. The tab controller routes between roots, while individual screens push feature nodes on their own navigation stack. The feed, search, and profile layouts use the device width at runtime.

## Build

Requires Theos plus the patched iOS 10.3 SDK from the Theos SDK release. The configured build is arm64 so it runs on the iPhone 5s and newer 64-bit devices.

```sh
export THEOS="$HOME/theos"
make package FINALPACKAGE=1
```

The project uses the classic linker mode because the iOS 10 SDK has older `.tbd` stubs. After a pull request is merged to `main`, GitHub Actions builds a `.deb` and publishes it as a prerelease. Open the repository's Releases page and download the newest package. On a jailbroken iPhone, open the `.deb` in Filza or install it with `dpkg -i` and refresh the icon cache with `uicache`.

Pull requests run the build and attach the `.deb` as a workflow artifact, without publishing a release.

## Next

1. Review layout and icons on a physical iPhone 5s.
2. Split the screen nodes and shared UI components into separate source files.
3. Connect read-only Instagram features behind replaceable service interfaces.
4. Add posting only after the viewing experience is stable.
