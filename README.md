# Insta10

An Objective-C UIKit interface prototype designed for iOS 10, with the iPhone 5s (320 × 568 pt) as the first layout target. Its screen structure follows Instagram 10.29 (2016–2017); it uses the original asset catalog for Instagram glyphs and the wordmark. Screens currently show neutral loading skeletons and do not sign in or contact Instagram.

## Interface nodes

- Home feed and post cards
- Explore grid with a Reels shelf controlled by the Options toggle
- Activity list
- Profile and profile grid
- Comments, Reels viewer, Options, and a placeholder node for later features
- Reels shelf toggle in Options
- Text demo mode (on by default) with `null` / zero placeholders and live switching
- Reference-matched 2016 repost and Direct inbox glyphs; translucent tab bar
- 4-inch launch image support so iPhone 5/5s use the full screen
- Shared vector icons drawn in the iOS 10 line style

Each screen is a separate `IGNodeController` subclass. The tab controller routes between roots, while individual screens push feature nodes on their own navigation stack. The feed, search, and profile layouts use the device width at runtime.

## Build

Requires Theos plus the patched iOS 10.3 SDK from the Theos SDK release. The configured build is arm64 so it runs on the iPhone 5s and newer 64-bit devices.

```sh
export THEOS="$HOME/theos"
make package FINALPACKAGE=1
```

The project uses the classic linker mode because the iOS 10 SDK has older `.tbd` stubs. Pushing to `main` triggers GitHub Actions, which builds the `.deb` and updates the stable [latest build](https://github.com/imcatsrsly/insta10/releases/download/latest/Insta10-latest.deb). On a jailbroken iPhone, open the `.deb` in Filza or install it with `dpkg -i` and refresh the icon cache with `uicache`.

Pull requests run the build and attach the `.deb` as a workflow artifact, without publishing a release.

## Next

1. Review layout and icons on a physical iPhone 5s.
2. Split the screen nodes and shared UI components into separate source files.
3. Connect read-only Instagram features behind replaceable service interfaces.
4. Add posting only after the viewing experience is stable.

## Local Zebra updates over Wi-Fi

Keep the Mac and iPhone on the same Wi-Fi network. Start the local source from this checkout:

```sh
python3 tools/local_repo.py
```

Open `http://<Mac-IP>:8890/` on the iPhone. The page can add the APT source to Zebra and has a button that refreshes the repo from the GitHub `latest` release. Add the source once; after pressing the refresh button, refresh Zebra's Sources and use **Upgrade** for Insta10. A package `postinst` refreshes the Home Screen registration, so manually running `uicache` or respringing should not be needed. The local source works only while this server is running and both devices can reach the Mac.
