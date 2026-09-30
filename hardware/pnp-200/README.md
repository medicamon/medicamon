# PnP-200: desktop pick-and-place with solder-paste dispenser

A concept 3D model of a small pick-and-place machine for small boards:

- **Y:** the bed (board plane) moves front to back, **200 mm** travel.
- **X:** the tool head moves left and right on a fixed gantry, 280 mm travel.
- **Z1 + C:** a vacuum pick nozzle moves up and down (40 mm) and rotates.
- **Z2:** a solder-paste syringe moves up and down (40 mm) on its own axis.

The layout follows the hand sketch (front and top views) and the photographed nozzle motor:

- **Top view:** a narrow bed carries the board on its front half and the tape strips across its back half.
- **Front view:** the syringe hangs on the left and the nozzle on the right. A vacuum hose loops from the nozzle over the gantry to a pump box on the outside of the right post.
- **Motor photo:** a hollow-shaft NEMA 11 with a rotary push-in fitting turns the nozzle.

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

The viewer and the SCAD file share the same parameter names and values. Both exports have the same bounding box, −281…305 × −240…240 × 0…422 mm, to within 0.2 mm (the difference is in how each tool draws the curved hose).

## Coordinate system

Units are mm. +X is right, +Y is toward the back, +Z is up, and the origin is the centre of the frame footprint at table level.

The nozzle, syringe and top camera all point down onto one line, the **tool line** at Y = 0. The gantry cannot move in Y, so a tool reaches bed point (u, v) only when the bed is at `y = −v`. Two things follow from this:

- **Everything the head picks from or places onto rides on the bed.** The board sits on the front half. Six tape strips run across the back half, along X, so the head steps along a strip in X and the bed selects the strip in Y.
- **Fixed stations sit on the tool line**, outside the bed's X range (±70 mm):
  - Up-looking camera at X = +160.
  - Reject bin at X = +110.
  - Needle-wipe cup at X = −160.

## Axes and parts

| Axis | Moves | Travel | Guide | Drive |
|---|---|---|---|---|
| Y | Bed: board fixture and 6 tape strips | 200 mm | 2 × MGN12 rail on 2020 risers, 4 × MGN12H block | NEMA 17, GT2 belt, 20T pulley |
| X | Tool carriage | 280 mm | 1 × MGN12H on the 2040 gantry beam | NEMA 17, GT2 belt, 20T pulley |
| Z1 | Vacuum nozzle | 40 mm | MGN9H | NEMA 11 + Tr8 lead screw |
| C | Nozzle rotation | 360° | – | OUKEDA OK28ZK34-084B-HM5 hollow-shaft NEMA 11 (see below) |
| Z2 | Paste syringe (10 cc, air pressure) | 40 mm | MGN9H | NEMA 11 + Tr8 lead screw |

- **Frame:** 460 × 480 mm made from 2040 extrusion, plus a 6 mm base plate.
  - Width is 562 mm including the X motor and idler brackets. The hose loop bulges out to X = +305 on the right.
  - Height is 366 mm to the top of the Z motors. The vacuum hose loop rises to about 420 mm.
- **Bed:** a 140 × 186 × 6 mm plate. It holds:
  - A 100 × 80 mm board pocket at the front, centred at bed Y = −48.
  - Six 130 mm strips of 8 mm tape at the back, on a 13 mm pitch starting at bed Y = +20. Each strip has 32 pockets at 4 mm. The pick end is on the left and the sprocket holes face the back.
- **Tool offsets in X:** nozzle +35 mm, top camera 0, syringe −35 mm.
- **Vision:**
  - A down-looking camera on the head finds the fiducials and tape pockets.
  - An up-looking camera on the frame checks each part's offset and rotation on the nozzle.
  - This is the usual OpenPnP camera layout, and LumenPnP uses the same one.
- **Vacuum:**
  - The pump and solenoid valve sit on a printed plate on the outside of the right post, below the X motor.
  - A 4 mm hose runs from the valve up past the X motor, over the gantry, and down in front of the Z motors to the rotary fitting on the nozzle motor.
- **Controller:** sits behind the bed's travel (Y > 193 mm), which the bed never reaches.

### C-axis motor (from the photo)

The label reads **OUKEDA OK28ZK34-084B-HM5**. I could not find a datasheet for this exact part. It is on resellers' lists, but none give specifications. This is how the model reads the part number:

| Part of the code | Reading | Basis |
|---|---|---|
| `28` | 28 mm frame (NEMA 11) | Same naming as `OK20STH30` (20 mm NEMA 8) and `OK42STH47` (42 mm NEMA 17) |
| `34` | 34 mm body length | Matches the photo; RobotDigg's comparable NEMA 11 PnP motor is 34 mm long |
| `084B` | Probably 0.8 A per phase, 4 leads | The same code pattern gives `42STH47-1684A` = 1.68 A and Oukeda `OK20STH30-0604B` = 0.6 A. The photo shows 4 wires. |
| `ZK` / `HM5` | Hollow shaft with an M5 thread at the rear | The rotary fitting in the photo screws into it. Comparable PnP motors take a KSH04-M5 fitting there. |

- **Photo stack:** the rear shaft carries a rotary push-in fitting for 4 mm hose, the same type as SMC KSH04-M5 (a ball-bearing rotary one-touch fitting for 4 mm tube, M5 thread). The shaft can therefore turn without twisting the hose.
- **Front shaft:** comparable motors have a 5 mm hollow front shaft that takes a Juki-style nozzle holder. The model assumes the same.

**Estimated sizes:** the heights above the motor are measured from the photo and are good to about ±2 mm:

| Item | Size |
|---|---|
| Shaft sleeve | Ø6 × 6 mm |
| M5 hex | 8 mm across flats × 5 mm |
| Bearing | Ø11 × 3 mm |
| Rotary body | Ø12 × 11 mm |
| Fitting | Ø8.5 × 7 mm |
| Release collar | Ø10 × 5 mm |

The whole stack is 37 mm tall. Measure your part and change `C_MOTOR_L` and the stack sizes in `nozzle_head()` if they differ.

**Before powering it:**
- Measure the coil resistance or ask the seller for the rated current before setting the driver current.
- Check that the hollow bore is clear end to end, since the vacuum path runs through it.

### Reach check

The carriage centre moves from X −140 to +140 (the viewer shows this as 0 to 280).

| Tool | X offset | Reach in X | Has to reach |
|---|---|---|---|
| Nozzle | +35 | −105 … +175 | Tape pockets −63 … +61 (pick end −63 … −39); board −50 … +50; reject bin +110; bottom camera +160 |
| Syringe | −35 | −175 … +105 | Board −50 … +50; wipe cup −160 |
| Top camera | 0 | −140 … +140 | Fiducials −45 … +45 |

In Y, the bed centre moves ±100 mm about the tool line.

- **Reach:** the board occupies bed Y −88 … −8 and the tape pockets are at +18.8 … +83.8, so both are well inside ±100.
- **Clearance:** the bed is 186 mm deep, so at the ends of travel its edges reach ±193 mm. That leaves 4 mm to the Y motor at the back.
- **Largest board:** the model's fixture holds a 100 × 80 mm board. With the tape strips where they are, the largest board is about **130 × 95 mm** (keeping a 5 mm fixture rim).

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
| Nozzle motor at safe height | 152 … 186 |
| Top of the nozzle's push-in fitting at safe height | 223 |
| Top-camera ring light | 138, a 42 mm working distance to the board |
| Bottom-camera ring light | 84, 37 mm below a part held at safe height |
| Vacuum pump / valve port | 130 … 190 / 209 |
| Gantry beam | 260 … 300 |
| Top of Z motors | 366 |

Under the bed, the Y belt loop runs at X = 0 in the 33 mm gap between the base plate and the bed. That gap is why the Y rails sit on 20 mm risers.

### Resolution

- **X and Y:** a 20-tooth GT2 pulley moves 20 × 2 mm = 40 mm of belt per turn. At 1/16 microstepping (200 × 16 = 3200 microsteps per turn), that is **80 microsteps/mm**, or 12.5 µm per microstep.
- **Z:** a Tr8 screw with lead L gives 3200 / L microsteps/mm. For example, an 8 mm lead gives 400/mm and a 2 mm lead gives 1600/mm.
- **C:** 3200 microsteps per turn gives 0.1125° per microstep.

These figures are command resolution, not placement accuracy. Belt stretch, frame stiffness and camera calibration limit real accuracy. OpenPnP uses the fiducials and bottom vision to correct board position and each part's offset and rotation on the nozzle.

## Demo cycle (viewer)

One loop takes about 1 minute at 1× speed:

1. Home.
2. Find the 3 fiducials with the top camera.
3. Dispense 26 paste dots.
4. Wipe the needle.
5. Place 12 parts: 4 × 0805 R, 4 × 0805 C, 2 × SOT-23 and 2 × 0603 LED, at 0°, 90° and 180°. For each part:
   1. Pick it from the left end of its tape strip. The bed moves back to bring the strip under the nozzle.
   2. Check it over the bottom camera.
   3. Rotate it, then place it. The bed moves forward to the board.

The tape parts sit with their long axis across the tape, which is along Y. The nozzle therefore turns to `C = rotation − 90°` before placing.

## Design notes

- **A moving bed shakes the placed parts.** Parts sit in wet paste on a bed that accelerates. Paste tack holds small passives, but limit Y acceleration and test with your heaviest parts. With this layout the bed travels 45–155 mm between each pick and its place, so Y acceleration matters more than X.
- **Vacuum hose length:**
  - In the model the hose path gets longer as the head moves left. Give the real hose enough slack for the full X travel, or carry it in a cable chain along the beam.
  - Keep the loop clear of the X belt and motor.
  - Shorter hose volume also means faster pick and release.
- **Paste dispensing:**
  - Air pressure (time-pressure) is the simplest method. The air volume in the barrel changes as the syringe empties, so dot size drifts.
  - A motor-driven piston or an auger valve dispenses a fixed volume regardless of viscosity or fill level.
  - The sketch shows no hose on the syringe, so a motor-driven syringe fits it too. The model still shows an air-driven barrel.
- **Paste and needle:**
  - Use a paste sold for dispensing, and match the powder size to the needle bore.
  - J-STD-005 powder sizes: Type 3 is 25–45 µm, Type 4 is 20–38 µm and Type 5 is 15–25 µm.
  - Needle bores (Nordson EFD): 20 ga is 0.61 mm, 22 ga is 0.41 mm.
- **Tape:** 8 mm carrier tape has 1.5 mm sprocket holes on a 4 mm pitch (EIA-481). 0603 and 0805 parts usually come in 4 mm pockets. The pocket centre sits 1.75 + 3.5 mm from the hole-side edge.
- **Controller:**
  - OpenPnP's GcodeDriver works with Smoothieware, Duet3D RepRapFirmware and grblHAL. Marlin also works, with limitations that the OpenPnP wiki describes.
  - The controller needs 5 motor axes (X, Y, Z1, Z2, C), or 6 with a motorised syringe.
  - It also needs outputs for the vacuum pump, the valves and the ring lights.
- **Not modelled:**
  - Cable chains (3 motors on the head, camera USB).
  - Endstops.
  - The Y-drive details under the bed.
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
- Hollow-shaft PnP motors:
  - RobotDigg NEMA 11 hollow-shaft stepper for pick and place (34 mm body, 5 mm hollow front shaft for Juki holders, rear M5 for KSH04-M5): <https://www.robotdigg.com/product/798/NEMA11-hollow-shaft-stepper-for-Pick-and-Place-Machine>
  - OK28ZK34-084B-HM5 reseller listing (no specifications): <https://www.amazon.com/OK20STH30-0604B-NK2-5-OK42STH47-1684AYT-OK35STH34-1004A-0K28ZK34-084B-HM5-0K20HC30-NK2-5-HM5/dp/B0FDFDHM9Y>
- Part-number pattern examples:
  - 42STH47-1684A at 1.68 A (Joy-it NEMA17-01 datasheet): <https://asset.conrad.com/media10/add/160267/c1/-/en/001597325DS00/list-technickych-udaju-1597325-joy-it-krokovy-motor-nema-17-01-nema-17-01-04-nm-168-a-prumer-hridele-5-mm.pdf>
  - Oukeda OK20STH30-0604B at 0.6 A: <https://compacttool.ru/motor-shagoviy-nema-8-ok20sth30-0604a-18-06a>
- SMC, *Rotary One-touch Fittings, Series KS/KX* (KSH04-M5: 4 mm tube, M5, ball-bearing rotary fitting): <https://www.smcpneumatics.com/pdfs/KS.pdf>
- GT2 2 mm pitch pulleys (20T pitch diameter 12.73 mm): <https://www.powerdrive.com/Downloads/ECatalogs/TimingBeltDrive/GT2%20Timing%20Pulley%20-%202mm%20Pitch.pdf>
- ECIA EIA-481-F, *Embossed and punched carrier taping of surface mount components*: <https://standards.globalspec.com/std/14462438/EIA-481-F>
- IPC J-STD-005A, *Requirements for Soldering Pastes* (powder types): <https://www.electronics.org/TOC/IPC-J-STD-005A.pdf>, and the Indium summary: <https://www.indium.com/blog/solder-powder-types-3-4-5-6-7/>
- Nordson EFD dispensing tips catalogue (gauge vs bore): <https://pdf.directindustry.com/pdf/nordson-efd/dispensing-tips/35688-146801.html>
- *Pushing Paste*, ASSEMBLY magazine (time-pressure vs positive-displacement and auger dispensing): <https://www.assemblymag.com/articles/82788-pushing-paste>
- OpenPnP wiki, *Motion Controller Firmwares*: <https://github.com/openpnp/openpnp/wiki/Motion-Controller-Firmwares>
- LumenPnP, an open-source OpenPnP machine with the same up- and down-camera layout: <https://github.com/opulo-inc/lumenpnp>
