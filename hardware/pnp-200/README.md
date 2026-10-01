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
| Y | Bed: board fixture and 6 tape strips | 200 mm | 2 × MGN12 rail (370 mm) on 2020 risers, 4 × MGN12H block | NEMA 17 0.9°, GT2 belt, 20T pulley |
| X | Tool carriage | 280 mm | 1 × MGN12H on the 2040 gantry beam | NEMA 17 0.9°, GT2 belt, 20T pulley |
| Z1 | Vacuum nozzle | 40 mm | MGN9H | NEMA 11 linear actuator, 2 mm-lead ball screw |
| C | Nozzle rotation | 360° | – | OUKEDA OK28ZK34-084B-HM5 hollow-shaft NEMA 11 (see below) |
| Z2 | Paste syringe (10 cc, air pressure) | 40 mm | MGN9H | NEMA 11 linear actuator, 2 mm-lead ball screw |

- **Frame:** 460 × 480 mm made from 2040 extrusion, plus a 6 mm base plate.
  - Width is 562 mm including the X motor and idler brackets. The hose loop bulges out to X = +305 on the right.
  - Height is 380 mm to the top of the Z motors. The vacuum hose loop rises to about 420 mm.
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
| Top of Z motors | 380 |

Under the bed, the Y belt loop runs at X = 0 in the 33 mm gap between the base plate and the bed. That gap is why the Y rails sit on 20 mm risers.

### Resolution

- **X and Y:** a 20-tooth GT2 pulley moves 20 × 2 mm = 40 mm of belt per turn. The 0.9° motor has 400 full steps per turn, so one full step is **0.1 mm**. At 1/16 microstepping that is 160 microsteps/mm, or 6.25 µm per microstep.
- **Z:** the 2 mm-lead ball screw on a 1.8° motor gives **0.01 mm** per full step, 1600 microsteps/mm at 1/16 (0.625 µm per microstep).
- **C:** 3200 microsteps per turn gives 0.1125° per microstep.

These figures are command resolution, not placement accuracy. Belt stretch, frame stiffness and camera calibration limit real accuracy. OpenPnP uses the fiducials and bottom vision to correct board position and each part's offset and rotation on the nozzle.

## Motors and drivers

The machine has four linear axes and one rotary axis:

- **X and Y:** the two main axes. X moves the head and Y moves the bed.
- **Z1 and Z2:** one up/down axis on each head.
- **C:** nozzle rotation, using the OUKEDA motor you already have.

### Selected motors

| Axis | Motor | Datasheet values | Drive | Full step | Microstep (1/16) |
|---|---|---|---|---|---|
| X | StepperOnline **17HM19-2004S**, NEMA 17, 0.9° | 2.0 A/phase, 46 N·cm holding, 1.45 Ω, 4.0 mH, 42 × 42 × 48 mm, 370 g | GT2 belt, 20T pulley, 40 mm/rev | 0.100 mm | 6.25 µm |
| Y | StepperOnline **17HM19-2004S** | same | same | 0.100 mm | 6.25 µm |
| Z1 | StepperOnline **11E18S1004BAM5-150RS**, NEMA 11 external linear actuator | 1.0 A/phase, 0.1 N·m holding, 3 Ω, 2 mH, 28 × 28 × 46 mm body, Ø6 × 150 mm ball screw, steel ball nut | 2 mm per rev | 0.010 mm | 0.625 µm |
| Z2 | StepperOnline **11E18S1004BAM5-150RS** | same | same | 0.010 mm | 0.625 µm |
| C | OUKEDA OK28ZK34-084B-HM5 (you have it) | 1.8°, probably 0.8 A (see above) | direct | 1.8° | 0.11° |

### Why this gives the heads the same accuracy

- **What limits a stepper's accuracy is the full step, not the microstep:**
  - Datasheets usually give step-angle accuracy as ±5 % of one full step (no load, non-cumulative).
  - Between full steps the motor is less exact. At 1/16 microstepping, one microstep has only sin(90°/16) ≈ 9.8 % of the holding torque, so friction and detent torque can stop it short.
  - Microstepping adds smoothness and resolution, not accuracy.
  - The figure to compare across axes is therefore **mm per full step**.
- **X and Y use 0.9° motors.** That halves the full step from 0.2 mm (1.8°) to 0.1 mm, which halves the motor's own error in mm (±5 µm instead of ±10 µm).
- **Z uses a small motor with a fine screw.** A 2 mm-lead screw turns one 1.8° step into 0.01 mm, ten times finer than X and Y. The motor's own error is about ±0.5 µm. A small NEMA 11 therefore positions the heads at least as accurately as the NEMA 17s position X and Y.
- **The ball nut matters for repeatability.** Its steel balls roll instead of sliding, which keeps backlash and friction low. Plastic (POM) nuts on trapezoidal screws are cheaper but looser. Approach the pick and place heights from the same direction every time (always moving down), so any remaining backlash is always taken up the same way.

### Torque margin

- **X axis:**
  - The carriage with both heads weighs roughly 1.5 kg. Accelerating it at 3 m/s² takes about 4.5 N, plus about 1 N of rail friction.
  - At the pulley's 6.37 mm pitch radius, 5.5 N is about **3.5 N·cm**. The motor holds 46 N·cm at full current.
  - That margin covers the torque loss at speed and lets you run the drivers below full current.
  - Y moves a lighter load (about 1 kg).
- **Z axes:**
  - A screw turns torque T into thrust F = 2π·η·T / lead.
  - Ball screws reach about 90 % efficiency (η). That gives 2π × 0.9 × 0.1 N·m / 0.002 m ≈ **280 N** at holding torque.
  - Each head weighs about 0.3 kg (3 N), so even 10 % of the torque is ample.

### Speed

- **X and Y:**
  - At 1/16, X and Y need 160 microsteps per mm, so 500 mm/s means 80,000 steps/s.
  - Check that your controller can output that rate.
  - Alternatively, run the drivers at 1/8 and let the TMC2209 interpolate to 256 microsteps internally. That halves the step rate.
- **Z with a 2 mm lead:**
  - Each turn moves 2 mm, so the model's 25 mm plunge is 12.5 turns. For example, that takes about 0.8 s at 15 rev/s. Check StepperOnline's thrust/speed curve before planning on higher speeds.
  - In practice the safe height only needs to clear your tallest part by a few mm. A 10 mm plunge takes about a third of that time.
  - If the nozzle Z still needs to be faster, StepperOnline's **11E13S1004HD5-150RS** (NEMA 11 linear, 5.08 mm-lead ACME screw, 1.0 A) is 2.5 × faster.
  - That motor still gives 0.025 mm per full step, which is 4 × finer than X/Y. The trade-off is a plastic nut with more backlash than the ball nut.

### Drivers and settings

Use a **TMC2209** for each of the five motors. It handles 2 A RMS (2.8 A peak) on a 4.75–29 V supply, sets current over UART, and interpolates any input to 256 microsteps. Run the motors on **24 V**, since a higher supply keeps torque up at speed.

| Motor | Suggested driver current | Why |
|---|---|---|
| X, Y (2.0 A rated) | 1.2–1.4 A RMS | 1.4 A RMS is 2.0 A peak, so it stays within the rating whether the 2.0 A is meant as RMS or peak. It also keeps the TMC2209 below its 2 A RMS limit and still leaves several times the torque X/Y need. |
| Z1, Z2 (1.0 A rated) | 0.6–0.7 A RMS | 0.7 A RMS is 1.0 A peak. Less current also means less heat on the moving head. |
| C (rating unconfirmed) | Start at 0.4–0.55 A RMS | 0.55 A RMS is 0.8 A peak. Raise it only after you confirm the rated current. |

**Chopper mode:** the TMC2209 offers two.
- StealthChop is silent at standstill and at low speed.
- SpreadCycle is more stable at high speed.
- The driver can switch between them by speed. Use SpreadCycle above a set speed for X/Y.

### Getting the accuracy out of the motors

- **Homing:**
  - Use optical or Hall-effect home switches on X, Y, Z1 and Z2.
  - Add OpenPnP's visual homing: the down camera finds a ~1 mm homing fiducial, so the machine's zero does not depend on how repeatable the switch is.
- **Backlash:** belts have little backlash. OpenPnP's backlash compensation (one-sided positioning) removes what remains.
- **Vision correction:** the board fiducials and the bottom camera correct board position and each part's offset and rotation. This is how hobby machines reach the roughly ±36 µm that 0402 parts need.
- **Missed steps:**
  - Open-loop steppers do not report lost steps. To detect them on Z, StepperOnline sells the same NEMA 11 linear family with a 300 PPR optical encoder (11E13S1004HD5-180RS-E22-300).
  - On X/Y, the fiducial and bottom-camera checks catch drift on every board.
- **Soft limits:**
  - Over the bed, Z never needs more than about 25 mm.
  - A full 40 mm plunge is only safe away from the stations: the collision check shows the nozzle reaching the bottom camera's ring light and the syringe needle reaching the wipe cup's rim.
  - Set OpenPnP's safe Z, and its Z limits per head, accordingly.

### Shopping list

| Qty | Part |
|---|---|
| 2 | StepperOnline 17HM19-2004S (NEMA 17, 0.9°, 2.0 A, 48 mm) |
| 2 | StepperOnline 11E18S1004BAM5-150RS (NEMA 11 linear, 2 mm ball screw, 150 mm) |
| 1 | OUKEDA OK28ZK34-084B-HM5 (already have) |
| 5 | TMC2209 drivers, or a controller board with at least 5 TMC2209 slots |
| 2 | GT2 20-tooth pulleys, 5 mm bore, 6 mm belt width |
| 1 | GT2 6 mm belt, about 2 m, plus 2 GT2 idlers |
| 1 | 24 V supply, 5 A or more; add your vacuum pump's draw |

The 3D model and viewer use these motors' dimensions:
- 48 mm NEMA 17 bodies.
- 46 mm NEMA 11 linear actuators with Ø6 × 150 mm screws.

A triangle-level collision test of the viewer geometry at 107 poses covered the full X, Y, Z1, Z2 and C range, including the station poses. It found no unintended contact apart from the full plunges noted above.

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
- OpenPnP wiki, *Backlash Compensation*: <https://github.com/openpnp/openpnp/wiki/Backlash-Compensation>, and *Fiducial Locator* (visual homing): <https://github.com/openpnp/openpnp/wiki/Fiducial-Locator>
- OpenPnP forum, *Reliable Placement of 0402-Sized Components* (±0.036 mm tolerance for 0402): <https://groups.google.com/g/openpnp/c/yQYekBUfxvA>
- StepperOnline 17HM19-2004S (NEMA 17, 0.9°, 2.0 A, 46 N·cm, 48 mm): <https://www.omc-stepperonline.com/nema-17-bipolar-0-9deg-46ncm-65-1oz-in-2a-2-9v-42x42x48mm-4-wires-17hm19-2004s>
- StepperOnline 11E18S1004BAM5-150RS (NEMA 11 linear, 2 mm ball screw): <https://www.omc-stepperonline.com/nema-11-external-ball-screw-linear-stepper-motor-1-0a-46mm-stack-screw-lead-2mm-0-07874-lead-length-150mm-11e18s1004bam5-150rs>
- StepperOnline 11E13S1004HD5-150RS (NEMA 11 linear, 5.08 mm ACME): <https://www.omc-stepperonline.com/nema-11-external-acme-linear-stepper-motor-1-0a-32-2mm-stack-screw-lead-5-08mm-0-2-lead-length-150mm-11e13s1004hd5-150rs>, and the 300 PPR encoder version: <https://www.omc-stepperonline.com/nema-11-external-acme-linear-stepper-motor-1-0a-32-2mm-stack-w-optical-rotary-encoder-300ppr-11e13s1004hd5-180rs-e22-300>
- Analog Devices (Trinamic), *TMC2209 datasheet* (2 A RMS / 2.8 A peak, 4.75–29 V, 256-microstep interpolation, StealthChop/SpreadCycle): <https://www.analog.com/media/en/technical-documentation/data-sheets/TMC2209_datasheet_rev1.09.pdf>
- MICROMO, *Microstepping: Myths and Realities* (incremental torque per microstep): <https://www.micromo.com/technical-library/stepper-motor-tutorials/microstepping-myths-and-realities>
- Leadshine 42HS series datasheet (step-angle accuracy ±5 %, full step, no load): <https://ww1.microchip.com/downloads/en/DeviceDoc/Leedshine%2042HS03%20Stepper%20Motor%20Datasheet.pdf>
- Ball screw efficiency (90–95 %): <https://en.wikipedia.org/wiki/Ball_screw>, and the thrust formula F = 2π·η·T / lead: <https://www.moonsindustries.com/article/thrust-generation-principle-linear-lead-screw-motor>
- LumenPnP, an open-source OpenPnP machine with the same up- and down-camera layout: <https://github.com/opulo-inc/lumenpnp>
