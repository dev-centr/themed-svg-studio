= Agent notes

Themed SVG Studio is a native D product for semantic SVG theme/token/binding
editing. It does not edit SVG geometry.

== Architecture

* Public reusable modules live under `source/themed_svg_studio/`.
* `protocol.d` owns protocol-v1 wire structs. `process_adapter.d` owns process
  launch and JSONL transport. Keep that boundary narrow while
  `@dev-centr/themed-svg` evolves.
* Use DUI as the app layer over Dew. Do not introduce Tauri, dlangui, or a
  direct Dew-only application architecture.
* TGC stays enabled in every product configuration.
* `studio.sdl` is user/application configuration. Do not replace it with JSON.
* Do not edit `assets/` or icons; product design owns those files.

== Verification

Run `dub test -c unittest`, `dub build -c cli`, and
`dub build -c gui-headless`. On Windows, also run `dub build -c gui`.
