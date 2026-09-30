# PnP-200: desktop pick-and-place with solder-paste dispenser

A concept 3D model of a small pick-and-place machine for small boards:

- **Y:** the bed (board plane) moves front to back, **200 mm** travel.
- **X:** the tool head moves left and right on a fixed gantry, 280 mm travel.
- **Z1 + C:** a vacuum pick nozzle moves up and down (40 mm) and rotates.
- **Z2:** a solder-paste syringe moves up and down (40 mm) on its own axis.

![PnP-200 in the interactive viewer](images/viewer.png)

| OpenSCAD assembly | Demo board after one cycle |
|---|---|
| ![OpenSCAD render](images/openscad-assembly.png) | ![Populated test board](images/board-closeup.png) |

## Files

| File | What it is |
|---|---|
| `pnp_200.scad` | Parametric OpenSCAD assembly. This is the source model. Pose sliders are in the Customizer, and `animate = true` runs a motion loop under View › Animate. |
| `viewer.html` | Interactive three.js viewer. You can jog each axis, run the demo cycle (fiducials, paste, pick, bottom-vision check, place), and show travel and overall dimensions. |
| `pnp_200.stl` | The whole assembly exported from OpenSCAD: binary STL, mm, Z up, pose X 140 / Y 100. GitHub shows it in its 3D viewer. |
| `pnp_200.glb` | A colour glTF export from the viewer with the demo board populated. It is Y-up, as the glTF format requires. |

The viewer and the SCAD file share the same parameter names and values. Both exports have the same bounding box, −281…281 × −240…240 × 0…366 mm, which confirms they match.

## Coordinate system

Units are mm. +X is right, +Y is toward the back, +Z is up, and the origin is the centre of the frame footprint at table level.

The nozzle, syringe and top camera all point down onto one line, the **tool line** at Y = 0. The gantry cannot move in Y, so a tool reaches bed point (u, v) only when the bed is at `y = −v`. Two things follow from this:

- **The feeders ride on the bed.** The strip feeders, the board fixture and the reject bin are all on the bed, so the Y axis brings them under the tools.
- **Fixed stations sit on the tool line**, outside the bed's X range (±120 mm). The up-looking camera is at X = +160 and the needle-wipe cup is at X = −160.

## Axes and parts

| Axis | Moves | Travel | Guide | Drive |
|---|---|---|---|---|
| Y | Bed: board fixture, 6 strip feeders, reject bin | 200 mm | 2 × MGN12 rail on 2020 risers, 4 × MGN12H block | NEMA 17, GT2 belt, 20T pulley |
| X | Tool carriage | 280 mm | 1 × MGN12H on the 2040 gantry beam | NEMA 17, GT2 belt, 20T pulley |
| Z1 | Vacuum nozzle | 40 mm | MGN9H | NEMA 11 + Tr8 lead screw |
| C | Nozzle rotation | 360° | – | NEMA 8 hollow-shaft motor (vacuum passes through the shaft) |
| Z2 | Paste syringe (10 cc, air pressure) | 40 mm | MGN9H | NEMA 11 + Tr8 lead screw |

- **Frame:** 460 × 480 mm made from 2040 extrusion, plus a 6 mm base plate. It is 562 mm wide including the X motor and idler brackets, and 366 mm tall to the top of the Z motors.
- **Bed:** a 240 × 180 × 6 mm plate. It carries a 100 × 80 mm board pocket and six 8 mm tape lanes on a 14 mm pitch.
- **Tool offsets in X:** nozzle +35 mm, top camera 0, syringe −35 mm.
- **Vision:**
  - A down-looking camera on the head finds the fiducials and feeder pockets.
  - An up-looking camera on the frame checks each part's offset and rotation on the nozzle.
  - This is the usual OpenPnP camera layout, and LumenPnP uses the same one.
- **Behind the bed's travel (Y > 190 mm):** controller box, vacuum pump and solenoid valve. The bed never reaches this area.

### Reach check

The carriage centre moves from X −140 to +140 (the viewer shows this as 0 to 280).

| Tool | X offset | Reach in X | Has to reach |
|---|---|---|---|
| Nozzle | +35 | −105 … +175 | Feeder pockets +36 … +106; board −95 … +5; bottom camera +160 |
| Syringe | −35 | −175 … +105 | Board −95 … +5; wipe cup −160 |
| Top camera | 0 | −140 … +140 | Fiducials −90 … 0 |

In Y, the bed centre moves ±100 mm about the tool line and the bed is 180 mm deep. Every point on the bed can therefore be brought under the tools.

The model's fixture holds a 100 × 80 mm board. With the feeders where they are, the largest board is about **120 × 160 mm** (keeping a 10 mm fixture rim).

### Height stack (from the table)

| Level | Z (mm) |
|---|---|
| Base plate top | 54 |
| Y rail seat (on 20 mm riser) | 74 |
| Bed underside / top | 87 / 93 |
| Board top (1.6 mm board, 3 mm fixture) | 96 |
| Tape top | 97 |
| Tool tips at Z = 0 (safe height) | 121, which is 25 mm above the board |
| Tool tips at Z = 40 (full plunge) | 81 |
| Top-camera ring light | 138, a 42 mm working distance to the board |
| Bottom-camera ring light | 84, 37 mm below a part held at safe height |
| Gantry beam | 260 … 300 |
| Top of Z motors | 366 |

Under the bed, the Y belt loop runs at X = 0 in the 33 mm gap between the base plate and the bed. That gap is why the Y rails sit on 20 mm risers.

### Resolution

- **X and Y:** a 20-tooth GT2 pulley moves 20 × 2 mm = 40 mm of belt per turn. At 1/16 microstepping (200 × 16 = 3200 microsteps per turn), that is **80 microsteps/mm**, or 12.5 µm per microstep.
- **Z:** a Tr8 screw with lead L gives 3200 / L microsteps/mm. For example, an 8 mm lead gives 400/mm and a 2 mm lead gives 1600/mm.

These figures are command resolution, not placement accuracy. Belt stretch, frame stiffness and camera calibration limit real accuracy. OpenPnP uses the fiducials and bottom vision to correct board position and each part's offset and rotation on the nozzle.

## Demo cycle (viewer)

One loop takes about 1 minute at 1× speed:

1. Home.
2. Find the 3 fiducials with the top camera.
3. Dispense 26 paste dots.
4. Wipe the needle.
5. Place 12 parts: 4 × 0805 R, 4 × 0805 C, 2 × SOT-23 and 2 × 0603 LED, at 0°, 90° and 180°. Each part is picked from its tape lane, checked over the bottom camera, rotated and then placed.

The tape parts sit with their long axis along Y. The nozzle therefore turns to `C = rotation − 90°` before placing.

## Design notes

- **A moving bed shakes the placed parts.** Parts sit in wet paste on a bed that accelerates. Paste tack holds small passives, but limit Y acceleration and test with your heaviest parts.
- **Paste dispensing:**
  - Air pressure (time-pressure) is the simplest method. The air volume in the barrel changes as the syringe empties, so dot size drifts.
  - A motor-driven piston or an auger valve dispenses a fixed volume regardless of viscosity or fill level.
  - The model shows an air-driven barrel.
- **Paste and needle:**
  - Use a paste sold for dispensing, and match the powder size to the needle bore.
  - J-STD-005 powder sizes: Type 3 is 25–45 µm, Type 4 is 20–38 µm and Type 5 is 15–25 µm.
  - Needle bores (Nordson EFD): 20 ga is 0.61 mm, 22 ga is 0.41 mm.
- **Tape:** 8 mm carrier tape has 1.5 mm sprocket holes on a 4 mm pitch (EIA-481). 0603 and 0805 parts usually come in 4 mm pockets.
- **Controller:** OpenPnP's GcodeDriver works with Smoothieware, Duet3D RepRapFirmware and grblHAL. Marlin also works, with limitations that the OpenPnP wiki describes. The controller needs 5 motor axes (X, Y, Z1, Z2, C), or 6 with a motorised syringe. It also needs outputs for the vacuum pump, the valves and the ring lights.
- **Not modelled:**
  - Cable chains for the head (3 motors, camera USB, vacuum and air lines).
  - Endstops.
  - Printed-part details. The orange parts are placeholders for size and position.

## Using the files

**OpenSCAD** (2021.01 or newer):

- Open `pnp_200.scad` and press F5 to preview.
- Set the pose (X, Y, Z1, Z2, C) in the Customizer.
- To run the motion loop, set `animate = true`, then use View › Animate with FPS 10 and Steps 200.
- F6 then F7 exports an STL. The full assembly takes about 1 minute.
- All dimensions are named constants in the `[Hidden]` section. Change them to match the parts you buy.

**Viewer:**

- Open `viewer.html` in a browser. It loads three.js 0.160 from jsDelivr, so it needs an internet connection.
- Drag to orbit, scroll to zoom and right-drag to pan.
- Moving a jog slider pauses the demo.

## References

- HIWIN, *MG Series Miniature Linear Guideway catalogue* (MGN9/MGN12 rail and block dimensions): <https://motioncontrolsystems.hiwin.com/Asset/MG-Series-Catalog.pdf>, and the MGN12H product page: <https://www.hiwin.de/en/Products/Linear-guideways/Blocks/Series-MGN-MGW/MGN/MGN12HZ0CM/p/MGN12HZ0CM>
- NEMA frame sizes:
  - NEMA 17 (42 mm face, 31 mm hole spacing): <https://eu.aspina-group.com/en/learning-zone/columns/what-is/034/>
  - NEMA 8 (20 mm) and NEMA 11 (28 mm): <https://www.omc-stepperonline.com/nema-8-stepper-motor>, <https://www.omc-stepperonline.com/nema-11-stepper-motor>
- GT2 2 mm pitch pulleys (20T pitch diameter 12.73 mm): <https://www.powerdrive.com/Downloads/ECatalogs/TimingBeltDrive/GT2%20Timing%20Pulley%20-%202mm%20Pitch.pdf>
- ECIA EIA-481-F, *Embossed and punched carrier taping of surface mount components*: <https://standards.globalspec.com/std/14462438/EIA-481-F>
- IPC J-STD-005A, *Requirements for Soldering Pastes* (powder types): <https://www.electronics.org/TOC/IPC-J-STD-005A.pdf>, and the Indium summary: <https://www.indium.com/blog/solder-powder-types-3-4-5-6-7/>
- Nordson EFD dispensing tips catalogue (gauge vs bore): <https://pdf.directindustry.com/pdf/nordson-efd/dispensing-tips/35688-146801.html>
- *Pushing Paste*, ASSEMBLY magazine (time-pressure vs positive-displacement and auger dispensing): <https://www.assemblymag.com/articles/82788-pushing-paste>
- OpenPnP wiki, *Motion Controller Firmwares*: <https://github.com/openpnp/openpnp/wiki/Motion-Controller-Firmwares>
- LumenPnP, an open-source OpenPnP machine with the same up- and down-camera layout: <https://github.com/opulo-inc/lumenpnp>
