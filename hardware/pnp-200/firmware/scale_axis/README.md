# scale_axis: closed-loop stepper axis with a glass scale

Arduino firmware for one pnp-200 axis.
- A 5 µm glass scale (5 V TTL, A/B/Z, like the NT-S DRO scales) measures the carriage.
- A TMC2209 drives the stepper.
- The board takes a small set of G-code commands over USB.
- Moves end within ±1 count (±5 µm) of the target on the scale, or ±2 counts at worst.

Use one board per axis: one for X, one for Y.

> **Status:** compiled for the Uno and tested in simulation only (see [Tests](#tests)). It has not run on real hardware yet, and it has not been tried with OpenPnP. Bring it up with the steps in [First start](#first-start), with a hand on the motor power switch.

## Files

| File | What it is |
|---|---|
| `scale_axis.ino` | The sketch: pins, interrupts, step timer, serial. ATmega328P only. |
| `config.h` | Your settings: steps/mm, directions, speeds, homing, switch polarity. |
| `axis_core.h` | Control loop and G-code, independent of the board. |
| `test/sim_test.cpp` | Runs `axis_core.h` against a simulated belt axis (`make` in `test/`). |
| `test/avr_sim.c` | Runs the compiled firmware in the simavr ATmega328P simulator. |

## What you need

- **Board:** an Arduino Uno, Nano or Pro Mini, 5 V / 16 MHz.
  - Their 5 V pins take the scale's 5 V TTL signals directly.
  - The sketch refuses to compile for other boards: it reads the port registers directly.
- **Driver:** a TMC2209 driver board (StepStick format).
- **Scale:** the glass scale. It needs the TTL version (single-ended A, B, Z). An RS-422 version (A, /A, B, /B) needs an AM26LS32 receiver in between.
- **Home switch:** one per axis, at the negative end.
- **Supply:** the motor supply (24 V), as in the main [README](../../README.md).

## Wiring

| Arduino | Goes to | Notes |
|---|---|---|
| 5V, GND | Scale +5 V and 0 V | The scale draws about 50 mA. Connect the scale cable's shield to GND at the Arduino end only. |
| D2 | Scale A | Pin-change interrupt INT0. |
| D3 | Scale B | INT1. |
| D4 | Scale Z (reference mark) | Optional. Used by homing; set `HOME_USE_REF_MARK 0` if unconnected. |
| D5 | TMC2209 STEP | |
| D7 | TMC2209 DIR | |
| D8 | TMC2209 EN | Low = motor on. The motor is off until a move, `G28` or `M17`. |
| D6 | Home switch to GND | See `HOME_ACTIVE_LOW`: 1 for a normally-open switch, 0 for normally-closed. Normally-closed is safer, because a broken wire then reads as "pressed". |
| 5V, GND | TMC2209 VIO, GND | Logic supply and common ground. |
| (none) | TMC2209 MS1 and MS2 to VIO | Both high = 1/16 microstepping. Check your board's table; boards differ. |
| (none) | TMC2209 VM, GND to 24 V | Add a 100 µF capacitor at VM. |
| D12 | Scope probe (optional) | High while the control loop runs, if `TICK_PROBE 1`. |

The scale's 9-pin connector has no standard pinout. Ask the seller which pins are +5 V, 0 V, A, B and Z before you connect it.

## Settings (`config.h`)

The defaults are for the pnp-200 X axis:
- Motor: Lin WO-4209L-01P, 0.9°.
- Microstepping: 1/16.
- Pulley: GT2 20T, which gives **160 steps/mm**.
- Scale: **0.005 mm per count**.

For Y, set `AXIS_LETTER 'Y'` and `MAX_POS_MM 200`.

| Setting | Default | Meaning |
|---|---|---|
| `MOTOR_DIR`, `SCALE_DIR` | 1 | Set to -1 to reverse. Find the right values with the first-start steps. |
| `MAX_SPEED_MM_S` | 150 | That is 24,000 steps/s and 30,000 counts/s. The compiler refuses settings above 40,000 of either. |
| `ACCEL_MM_S2` | 2000 | |
| `MAX_FOLLOW_ERR_MM` | 1.0 | Stop with a fault if the scale and the plan differ by more. This catches stalls, slipping pulleys and a wrong `SCALE_DIR`. |
| `DEADBAND_COUNTS` / `HOLD_BAND_COUNTS` | 1 / 2 | A move aims for ±1 count and accepts ±2. At rest it corrects only beyond ±2. |
| `SETTLE_MS`, `TRIM_SPEED_MM_S`, `MAX_TRIMS` | 20, 1.0, 10 | The end-of-move correction (see [How it works](#how-it-works)). |
| `HOME_*`, `REF_*` | | Homing speeds, backoff, search distance and the position given to home. |

## Commands

The board sends `ok` or `error: …` back for every line. It answers only when the axis is still. A command sent during a move waits until the move ends, so a long reply cannot delay the control loop.

| Command | Does |
|---|---|
| `G0 X<mm> F<mm/min>` (or `G1`) | Move. Replies `ok` at once; `M400` waits for the end. `F` is remembered. |
| `G28` | Home: fast to the switch, back off, slow to the switch, then to the first reference mark. Replies when done. |
| `G92 X<mm>` | Set the current position. It also counts as homed. |
| `G90` / `G91` | Absolute or relative moves. |
| `M400` | Wait until the axis has stopped and settled. Replies `error: …` if the axis is in a fault. |
| `M114` | Position, as `X:<scale> T:<target> E:<error> M:<motor> C:<scale count>`. |
| `M119` | Home switch state. |
| `M122` | Diagnostics: mode, missed scale edges, largest error in the last move, trim failures, late control ticks. |
| `M17` / `M18` | Motor on / off. With the motor off, `M114` still reads the scale. |
| `M92 X<steps/mm>`, `M203 X<mm/s>`, `M204 S<mm/s²>` | Change steps/mm, maximum speed or acceleration until the next reset. |
| `M900 X<mm>` | Test move with the scale ignored. Reports motor mm against scale mm and their ratio. |
| `M901 S0` / `S1` | Open loop (steps only) / closed loop (the default). |
| `M999` | Clear a fault. Homing again is not needed: the scale still knows where the carriage is. |
| `!` | Stop now, even in the middle of a line. The axis decelerates and goes into a fault. |

Settings changed with `M92`, `M203` and `M204` are lost at reset. To keep them, put them in `config.h`.

## First start

Open the Arduino Serial Monitor at 115200 baud with "Newline" line endings.

1. **Scale.** Keep the motor power off.
   - Push the carriage by hand and send `M114`.
   - `C:` should rise when the carriage moves toward +X. If it falls, set `SCALE_DIR -1`. If it does not change, check the wiring.
   - `M122` should show 0 missed edges.
2. **Motor direction.** Turn the motor power on.
   - Send `M901 S0`, then `G92 X100`, then `G0 X105`. The carriage should move toward +X.
   - If it moves the other way, set `MOTOR_DIR -1` and upload again.
3. **Steps per mm.** Send `M901 S1`, `G92 X100`, then `M900 X20`.
   - The ratio should be close to 1.000. A wobbly pulley alone can shift it by a few tenths of a percent.
   - A negative ratio means one of the two directions is still wrong.
4. **Switch.** Send `M119` while pressing the switch. If it reads backwards, flip `HOME_ACTIVE_LOW`.
5. **Home.** Send `G28`, then `G0 X100 F6000`, then `M400` and `M114`.
6. **Watch `M122`** after a few dozen moves.
   - *Missed edges:* means a noisy scale cable or counting too fast.
   - *Trim failures:* means the carriage would not settle; tension the belt, or raise `SETTLE_MS`.
   - *Overruns:* means the control loop was late during a move.

   All three should stay at 0.

## How it works

The scale sits on the far side of a springy belt. After every move the carriage rings at the belt's resonance (tens of Hz). Feeding the scale back continuously through that resonance can make the loop unstable. My first version did that, and in simulation it oscillated until it faulted. So the scale is used in two ways that cannot destabilise:

1. **During a move:**
   - The motor follows a trapezoidal speed profile by counting its own steps, which is exact and has no resonance in the loop.
   - The scale is only compared with the plan. A difference above `MAX_FOLLOW_ERR_MM` stops the axis with a fault.
2. **At the end of a move, the axis trims:**
   - It waits until the scale is steady within one count for `SETTLE_MS`.
   - Then it creeps toward the target at `TRIM_SPEED_MM_S`, reading the scale every millisecond.
   - It stops as soon as the scale is inside the band. Near the target it also stops as soon as the carriage starts to move.

   The second rule matters because of friction. The carriage sticks until the belt has stretched by about friction ÷ belt stiffness (around 15 µm for 1 N on 70 N/mm). It then jumps, and stopping the creep at once keeps that jump from being driven further. The axis repeats the creep until it is steady inside ±1 count, or ±2 counts after four tries.

At rest it holds the same way: it corrects whenever someone or something moves the carriage by more than two counts.

The interrupts are kept short:
- **Scale interrupt:** 82 cycles (5.1 µs), counted from the compiled code. It keeps a 16-bit count that the main loop extends to 32 bits every millisecond.
- **Missed edges:** if both scale lines change before the interrupt runs, the decoder adds 2 in the last direction and counts it in `M122`.
- **Step interrupt:** about 100 cycles. Steps are timed by Timer1.

## Tests

`make` in `test/` runs `sim_test`. It puts `axis_core.h` on a simulated belt axis with these errors:
- a pulley off-centre by 25 µm;
- a 70 N/mm belt carrying a 2 kg carriage;
- 1 N of friction;
- ±5 µm microstep error and 3 µm of lost motion;
- a scale that reads 20 ppm long.

Results:

| Test | Result |
|---|---|
| 200 random moves, open loop, vs an ideal ruler | 50.7 µm max, 22.4 µm RMS |
| Same moves, closed loop, vs an ideal ruler | **10.1 µm max, 3.7 µm RMS** (includes the scale's own 20 ppm error) |
| Same moves, closed loop, vs the scale | 10 µm max; 197 of 200 within ±5 µm |
| Time per move, including settling | 0.69 s closed loop, 0.63 s open loop |
| Homing repeatability on the reference mark, 5 starts | 2.7 µm |
| Belt jumps 0.4 mm during a move | Ends 3 µm from the target |
| Motor stalls during a move | `M400` replies `error: following error`; after `M999` it moves to within 3.4 µm without homing again |
| `SCALE_DIR` set wrong | Fault after 1.15 mm of travel |
| Carriage pushed 63 µm while holding | Back to within 1.7 µm |
| 36 combinations of belt stiffness, damping, friction and pulley wobble | No faults. A move gave up trimming only with a very soft, nearly undamped belt (20 N/mm, ζ = 0.02), and still ended within 19 µm. |

`avr_sim.c` runs the compiled Uno firmware in simavr, a cycle-accurate ATmega328P simulator, with a simulated motor and scale on its pins.

| Check | Result |
|---|---|
| Homing on the reference mark | Within 1 count |
| 4 moves at 150 mm/s | Within 3 µm of the true position |
| Counting while the motor steps at 24,000 steps/s | Exact up to 90,000 counts/s, three times what 150 mm/s needs |
| Control loop at 30,000 counts/s | 387 µs mean, 481 µs max of the 1,000 µs budget |
| Control loop at 90,000 counts/s | 830 µs max |
| Missed edges, late ticks | 0 |

Build the sketch with `TICK_PROBE 1` to get the timing figures, then run `make avr ELF=path/to/scale_axis.ino.elf`.

All of this is simulation. A real belt, pulley and scale will differ: measure with `M122` and `M900` on the machine.

## Limits

- **Speed:** 150 mm/s by default. The Uno counts the scale in software. It counted correctly at 90,000 counts/s in simulation, but real scales have uneven edge spacing, so leave the margin.
  - For faster axes, port `scale_axis.ino` to a board with a hardware quadrature counter, such as an STM32 timer in encoder mode or the RP2040's PIO. `axis_core.h` stays the same.
- **No straight-line paths:** two boards move X and Y independently. Paths between points are not straight lines, which is fine for pick-and-place moves made at safe Z.
- **Abbe offset:** the scale measures the carriage where the read head is mounted. Tilt between there and the nozzle is not seen; mount the scales as the main [README](../../README.md#glass-scales-optional) describes.
- **Scale accuracy:** accuracy is the scale's own. 5 µm is its resolution, not its accuracy.

## Using it with OpenPnP (not yet tried)

OpenPnP 2.x can drive several controllers: add a GcodeDriver per board and assign each axis to its board's driver. The commands below are for the X board; for Y, use `Y` in place of `X`.

| OpenPnP command | Value |
|---|---|
| `COMMAND_CONFIRM_REGEX` | `^ok.*` |
| `COMMAND_ERROR_REGEX` | `^error.*` |
| `HOME_COMMAND` | `G28` |
| `MOVE_TO_COMMAND` | `G0 {X:X%.4f} {FeedRate:F%.0f}` |
| `MOVE_TO_COMPLETE_COMMAND` | `M400` |
| `SET_GLOBAL_OFFSETS_COMMAND` | `G92 {X:X%.4f}` |
| `GET_POSITION_COMMAND` | `M114` |
| `POSITION_REPORT_REGEX` | `^X:(?<X>-?\d+\.\d+).*` |

Driver settings:
- Raise the driver's timeout above the homing time (up to about 15 s).
- Set a connect wait of about 2 s, because the Uno resets when the port opens.
- Leave OpenPnP's backlash compensation off for these axes; the scale already removes backlash.

## References

- TMC2209 datasheet (step/dir, EN, MS1/MS2): <https://www.analog.com/media/en/technical-documentation/data-sheets/TMC2209_datasheet_rev1.08.pdf>; microstep pin tables: [BTT wiki](https://bttwiki.com/TMC2209.html), [FYSETC](https://fysetc.github.io/Silent2209)
- ATmega48A/PA/88A/PA/168A/PA/328/P datasheet, DS40002061 (INT0/INT1, pin-change interrupts, Timer1): <https://www.microchip.com/DS40002061>
- Closed-loop steppers with glass scales in LinuxCNC (velocity mode, PID, dual loops): [forum thread](https://forum.linuxcnc.org/49-basic-configuration/34750-stepper-motors-and-linear-scale-closed-loop-setup), [steppers and linear encoders](https://forum.linuxcnc.org/10-advanced-configuration/223-steppers-linear-encoders)
- OpenPnP drivers: [GcodeDriver](https://github.com/openpnp/openpnp/wiki/GcodeDriver), [Advanced Motion Control](https://openpnp-wiki.readthedocs.io/en/add-mkdocs/wiki/Advanced-Motion-Control.html)
- simavr: <https://github.com/buserror/simavr>
- J. B. Bryan, "The Abbé principle revisited: an updated interpretation", *Precision Engineering* 1(3), 129–132 (1979)
