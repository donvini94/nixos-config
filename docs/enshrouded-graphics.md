# Enshrouded graphics tuning

## Evidence and limits

The current [ComputerBase 1.0 review](https://www.computerbase.de/artikel/grafikkarten/enshrouded-benchmark-test.99840/) includes menu screenshots, visually checked for the controls below. Its screenshots are German; [this English illustrated walkthrough](https://allthings.how/enshrouded-pc-settings-explained-display-3d-render-scale-and-quality-presets/) supplies most English labels. English capitalization and full value cycles still need checking in-game, especially Shadows and Texture Filtering.

The English walkthrough uses **Balance** for some middle settings; DLSS uses **Balanced**. Internal log values such as Medium/High are not the menu vocabulary. Older guides include Texture Resolution and Volumetric Shadow Quality; do not assume these are separate current controls. Voxels and Voxel Detail Models are separate controls in the current screenshots.

[Keen's 1.0 notes](https://enshrouded.com/en-US/news/release-trailer-changelog-everything-you-need-to-wait-for-tomorrow) describe major changes to distant voxel rendering, global illumination and point-light shadows. [Early Access comparisons](https://www.computerbase.de/artikel/gaming/enshrouded-early-access-benchmark-test.87996/) can suggest what to test, but cannot establish current per-setting gains.

No available benchmark establishes the optimum for this exact game build, RTX 3090 at 5120×2160, Proton and lsfg-vk combination. The following is a starting preset, not a measured FPS promise.

## Quality/performance starting point

Set Quality Preset to Custom. Keep native output resolution, use DLSS Balanced and initially leave 3D Render Scale under its automatic/default control. Do not prescribe an additional manual scale without verifying its interaction with DLSS.

| Control | Starting point |
| --- | --- |
| Window Mode | Fullscreen |
| Resolution | Native output resolution |
| Anti-Aliasing | DLSS |
| DLSS | Balanced |
| Texture Filtering | Quality; raise to the highest offered option if affordable |
| Shadows | Middle quality option |
| Contact Shadows | On |
| Point Light Shadows | Performance |
| Indirect Lighting | Balance / middle option |
| SSAO | Performance |
| Reflections | Performance |
| Water | Balance / middle option |
| Fog | Performance |
| Models | Quality |
| Distant Objects | Quality |
| Voxels | Quality |
| Tessellation | Performance |
| Voxel Detail Models | Balance / middle option |
| Small Foliage | Balance / middle option |
| NVIDIA Reflex | On |

Preserve distance and geometry detail initially; reduce individual lighting effects rather than blindly applying an all-low preset. Compare DLSS Performance if the base render rate remains insufficient, or DLSS Quality if there is headroom. Performance-mode entries are candidates for later increases, not claims of proven current savings.

Measure the same short route through forest, Shroud and a lit base. Check frame-time consistency as well as average FPS, including the overhead of frame generation. Make display/V-Sync/HDR changes without LSFG active, then restart before comparing; do not change multiple variables at once.

## lsfg-vk pacing constraint

The [official lsfg-vk pacing documentation](https://lsfg-vk.dev/docs/configuration/pacing-modes) currently lists only Vsync pacing. It force-enables V-Sync to avoid skipped frames, says proper pacing requires generated output to match monitor refresh, and warns of possible VRR interaction. Generic advice to enable VRR and disable V-Sync is therefore not established for this implementation.

At fixed 120 Hz, target 60 real FPS with 2× generation if sustainable. 40 real FPS with 3× generation is an alternative to test, with lower input responsiveness and potentially more artifacts and generation cost. A 45→90 or 50→100 target at fixed 120 Hz is a pacing compromise, not guaranteed even delivery. Do not assume custom 90/100 Hz display modes exist.

A frame cap must limit the intended stage: base rendering before generation, not generated output. A foreground in-game limiter and the ordering of external Vulkan-layer limiters remain unverified.

[Dell's specifications](https://www.dell.com/en-us/shop/dell-ultrasharp-40-curved-thunderbolt-hub-monitor-u4025qw/apd/210-bmdp/monitors-monitor-accessories) explicitly advertise HDMI 2.1 VRR on the U4025QW, but do not explicitly establish DisplayPort VRR. Verify actual driver/connector support before relying on it.
