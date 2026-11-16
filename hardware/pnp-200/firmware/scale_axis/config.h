// config.h: settings for one scale-feedback axis. Edit, then upload.
//
// Defaults are for the pnp-200 X axis: Lin WO-4209L-01P (0.9 deg, 400 full
// steps/rev), TMC2209 at 1/16, GT2 20T pulley (40 mm/rev), 5 um glass scale.
// For the Y axis change AXIS_LETTER to 'Y' and MAX_POS_MM to 200.
#pragma once

// ---- Axis --------------------------------------------------------------------
#define AXIS_LETTER        'X'      // the G-code letter this board answers to

#define STEPS_PER_MM       160.0f   // 400 full steps x 16 microsteps / 40 mm
#define MOTOR_DIR          1        // -1 if positive moves run the wrong way
#define MM_PER_COUNT       0.005f   // 5 um per scale count
#define SCALE_DIR          1        // -1 if M900 reports a negative ratio

#define MIN_POS_MM         0.0f     // soft limits after homing
#define MAX_POS_MM         230.0f

// ---- Motion ------------------------------------------------------------------
// An Uno counts the scale in software, so speed is limited by its count rate:
// 150 mm/s is 30,000 counts/s. See README.md before raising it.
#define MAX_SPEED_MM_S     150.0f
#define DEFAULT_SPEED_MM_S 100.0f   // used until a G0/G1 sends F (mm/min)
#define ACCEL_MM_S2        2000.0f

// ---- Closed loop -------------------------------------------------------------
// During a move the motor follows the plan by its step count and the scale is
// only checked. At the end: wait until the scale is steady, creep toward the
// target until the scale is inside the deadband, repeat (see README.md).
#define MAX_FOLLOW_ERR_MM  1.0f     // stop with a fault if the scale and the plan differ by more
#define DEADBAND_COUNTS    1        // done within +-1 count (+-5 um)
#define HOLD_BAND_COUNTS   2        // at rest, correct only beyond +-2 counts
#define SETTLE_MS          20       // steady within 1 count for this long
#define TRIM_SPEED_MM_S    1.0f     // creep speed for the final correction
#define MAX_TRIMS          10       // creeps per move before giving up (counted in M122)

// ---- Homing (G28) ------------------------------------------------------------
#define HOME_DIR           -1       // the switch is at the negative end
#define HOME_FAST_MM_S     20.0f
#define HOME_SLOW_MM_S     1.0f
#define HOME_BACKOFF_MM    2.0f
#define HOME_MAX_TRAVEL_MM 260.0f   // fault if the switch is not found within this
#define HOME_POS_MM        0.0f     // position given to the home point
#define HOME_USE_REF_MARK  1        // 1: after the switch, zero on the scale's reference mark
#define REF_SEARCH_MM      60.0f    // marks are often every 50 mm
#define REF_SEARCH_MM_S    2.0f
#define REQUIRE_HOMING     1        // refuse moves until G28 or G92

// ---- Inputs and serial -------------------------------------------------------
#define HOME_ACTIVE_LOW    1        // 1: switch closes to GND when pressed (NO switch)
                                    // 0: normally-closed switch to GND (safer, see README)
#define REF_ACTIVE_HIGH    1        // reference pulse polarity
#define SERIAL_BAUD        115200
#define TICK_PROBE         0        // 1: D12 is high while the control loop runs (for a scope)
