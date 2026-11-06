# Insta10

An Objective-C UIKit client shell designed for iOS 10, with the iPhone 5s (320 × 568 pt) as the first layout target. The current screens use local sample content and custom drawn artwork; they do not sign in or contact Instagram.

## Interface nodes

- Home feed and post cards
- Explore grid with a Reels shelf controlled by the Options toggle
- Activity list
- Profile and profile grid
- Comments, Reels viewer, Options, and a placeholder node for later features

Each screen is a separate `IGNodeController` subclass. The tab controller routes between roots, while individual screens push feature nodes on their own navigation stack. The feed, search, and profile layouts use the device width at runtime.

## Build

Requires Theos plus a **device** iOS 10.3 SDK. The SDK currently present in the development environment has simulator-only linker stubs, so it cannot produce an installable phone package.

```sh
export THEOS="$HOME/theos"
make package
```

The configured architectures are armv7 and arm64. On a jailbroken device, Theos installs the package with `dpkg` and `uicache`; an IPA can also be packaged for AppSync Unified.

## Next

1. Review spacing and typography on the iPhone 5s.
2. Split the screen nodes and shared UI components into separate source files.
3. Connect read-only Instagram features behind replaceable service interfaces.
4. Add posting only after the viewing experience is stable.
