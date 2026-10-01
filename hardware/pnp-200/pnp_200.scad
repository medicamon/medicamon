// PnP-200: desktop pick-and-place machine with solder-paste dispenser
// Concept assembly, parametric.
//
// Kinematics
//   Y  bed (board plane) moves front/back, 200 mm travel
//   X  tool carriage moves left/right on a fixed gantry, 230 mm travel
//   Z1 vacuum nozzle up/down, 40 mm, plus C rotation (hollow-shaft NEMA 11)
//   Z2 paste syringe up/down, 40 mm; the plunger is pushed by a NEMA 17 linear stepper
//   Each Z: T8 lead screw in two KP08 bearings + anti-backlash nut, guided by an
//   8 mm rod in two SK8 supports with an SCS8UU bearing block
//
// Units: mm. +X right, +Y toward the back, +Z up.
// Origin: centre of the frame footprint at table level.
// The tool line (nozzle, syringe and top camera axes) is the plane Y = 0,
// so a bed-local point (u, v) is under a tool when bed_y = -v.
//
// OpenSCAD 2021.01 or newer. F5 to preview. View > Animate (FPS 10, Steps 200)
// with animate = true runs the motion loop. Pose values are in the Customizer.

/* [Pose, machine coordinates] */
// Bed position Y (0 = bed fully forward)
pose_y = 100; // [0:1:200]
// Carriage position X (0 = far left)
pose_x = 115; // [0:1:230]
// Nozzle plunge below safe height
pose_z_nozzle = 0; // [0:0.5:40]
// Syringe plunge below safe height
pose_z_paste = 0; // [0:0.5:40]
// Nozzle rotation C in degrees
pose_c = 0; // [-180:1:180]
// Drive the pose from $t (View > Animate)
animate = false;

/* [Display] */
show_envelope = false;
show_parts_on_board = true;

/* [Hidden] */
$fn = 32;
E = 0.01;

// ---------------------------------------------------------------- travel
Y_TRAVEL = 200;
X_TRAVEL = 230;
Z_TRAVEL = 40;

// ---------------------------------------------------------------- frame
FRAME_W = 460;            // X
FRAME_D = 480;            // Y
FOOT_H = 8;
BASE_H = 40;              // 2040 extrusion standing on edge
PLATE_T = 6;              // cast tooling plate
Z_BASE_TOP = FOOT_H + BASE_H;        // 48
Z_PLATE = Z_BASE_TOP + PLATE_T;      // 54, top of base plate

// ---------------------------------------------------------------- linear guides
// HIWIN MGN catalogue values: rail width WR, rail height HR,
// block width W, overall length L, steel body length L1, assembly height H, H1, rail hole pitch P.
MGN12 = [12, 8, 27, 45.4, 32.4, 13, 3, 25];
MGN9  = [ 9, 6.5, 20, 39.9, 28.9, 10, 2, 20];
function g_WR(g) = g[0];
function g_HR(g) = g[1];
function g_W(g)  = g[2];
function g_L(g)  = g[3];
function g_L1(g) = g[4];
function g_H(g)  = g[5];
function g_H1(g) = g[6];
function g_P(g)  = g[7];

// ---------------------------------------------------------------- Y axis (bed)
Y_RAIL_X = 50;            // rails at X = +/-50
Y_RAIL_LEN = 370;                     // blocks reach +/-178; ends clear the Y motor at Y = 197
RISER_H = 20;             // 2020 riser under each Y rail
Z_YRAIL = Z_PLATE + RISER_H;          // 74, rail seat
BED_W = 140;              // narrow bed: board at the front, tape strips across the back
BED_D = 186;              // bed ends reach Y = +/-193; the Y motor starts at 197
BED_T = 6;
Z_BED = Z_YRAIL + g_H(MGN12);         // 87, bed underside
Z_BED_TOP = Z_BED + BED_T;            // 93
Y_BLOCK_OFF = 55;                     // bearing blocks at bed-local Y = +/-55
Y_PULLEY_Y = 218;                     // drive pulley (back) and idler (front)
Z_YBELT = 76;                         // belt loop centre height

// ---------------------------------------------------------------- board and feeders (bed-local)
FIX_T = 3;
FIX_RIM = 5;
PCB_W = 100;
PCB_D = 80;
PCB_T = 1.6;
PCB_C = [0, -48];                     // front half of the bed
Z_PCB_TOP = Z_BED_TOP + FIX_T;        // 96
FEEDER_N = 6;                         // strips across the bed (tape runs along X)
FEEDER_Y0 = 20;                       // first strip centre, bed-local Y
FEEDER_PITCH = 13;
FEEDER_X = [-65, 65];
Z_TAPE_TOP = Z_BED_TOP + 4;           // 97
TAPE_POCKET_PITCH = 4;                // EIA-481, 8 mm tape
TAPE_PART_OFF = -1.25;                // pocket centre from strip centre (1.75 + 3.5 from the hole-side edge)

// ---------------------------------------------------------------- gantry
POST_X = FRAME_W/2 - 10;              // 220, post centre
TOOL_Y = 0;
ZC_FRONT = 24;                        // Z plate front face (tools mount here)
ZC_T = 6;                             // Z plate thickness

// Z guide and drive for each head (the photographed parts), behind the Z plate.
SCS8UU  = [34, 30, 22, 11];           // bearing block: width X, length Z, height Y, shaft height
SK8     = [42, 14, 32.8, 20, 21];     // shaft support: width X, thickness Z, height Y, shaft height, tower width
KP08    = [55, 13, 28, 15];           // pillow block: length X, width Z, height Y, centre height
NUT_BLK = [34, 36, 12];               // anti-backlash nut block (OpenBuilds type): X, Z, Y
COUPLER = [19, 25];                   // flexible coupler 5 x 8 mm: diameter, length
SCS_SPACER = 3;                       // under the SCS8UU, so the SK8 clears the Z plate
ROD_DX = 26;                          // guide rod beside the screw, on the outer side of each head
ROD_Y = ZC_FRONT + ZC_T + SCS_SPACER + SCS8UU[3];   // 44
MAIN_FRONT = ROD_Y + SK8[3];          // 64, main carriage plate front face
SCREW_Y = MAIN_FRONT - KP08[3];       // 49
NUT_SPACER = SCREW_Y - NUT_BLK[2]/2 - (ZC_FRONT + ZC_T);   // 13, under the nut block
MAIN_T = 8;
XRAIL_SEAT = MAIN_FRONT + MAIN_T + g_H(MGN12); // 85, beam front face
BEAM_Y = XRAIL_SEAT + 10;             // 95, beam centre (20 deep)
Z_BEAM = 280;                         // beam centre (40 tall)
Z_POST_TOP = Z_BEAM - 20;             // 260
TOOL_DX = 40;                         // nozzle at +40, syringe at -40
Z_TIP_SAFE = 121;                     // tool tip height at Z = 0
Z_TIP_LOW = Z_TIP_SAFE - Z_TRAVEL;    // 81
// Moving parts are placed above the tool tip; fixed parts in machine Z.
ZP_Z = [25, 125];                     // Z plate, above the tip
NUT_Z0 = 56;                          // nut block bottom, above the tip
SCS_Z0 = NUT_Z0 + NUT_BLK[1];         // 92, SCS8UU bottom, above the tip
KP08_BOT_Z = Z_TIP_LOW + NUT_Z0 - 2 - KP08[1];       // 122, just below the nut at full plunge
SK8_BOT_Z  = KP08_BOT_Z - 1 - SK8[1];                // 107
SK8_TOP_Z  = Z_TIP_SAFE + SCS_Z0 + SCS8UU[1] + 2;    // 245, just above the SCS8UU at safe height
KP08_TOP_Z = SK8_TOP_Z + SK8[1] + 1;                 // 260
COUPLER_Z  = KP08_TOP_Z + KP08[1] + 1;               // 274
MAIN_W = 180;
MAIN_Z = [SK8_BOT_Z - 2, COUPLER_Z + COUPLER[1] + 1];   // [105, 300]
SCREW_Z = [KP08_BOT_Z - 2, COUPLER_Z + COUPLER[1]/2];   // T8 screw cut to about 165 mm
ROD_Z = [SK8_BOT_Z, SK8_TOP_Z + SK8[1]];               // 8 mm rod cut to about 152 mm
// Motors (see README, "Motors and drivers")
XY_MOTOR_L = 48;                      // Lin Engineering WO-4209L-01P: NEMA 17, 0.9 deg, 1.7 A, 48 mm body (StepperOnline 17HM19-2004S equivalent)
Z_MOTOR_L = 48;                       // same motor on each Z screw (5 mm shaft into the 5 x 8 coupler)
T8_LEAD = 8;                          // Tr8x8, the usual lead for OpenBuilds-type nut blocks; confirm yours
X_PULLEY_X = 255;                     // clear of the beam end (230) by the motor half-width
Z_XBELT = 315;

// ---------------------------------------------------------------- fixed stations on the tool line
BOTTOM_CAM_X = 150;
PURGE_X = -150;
REJECT_X = 95;

// ---------------------------------------------------------------- nozzle head (C axis)
// OUKEDA OK28ZK34-084B-HM5 as photographed: 28 mm frame, 35.6 mm measured over body and
// front boss, hollow shaft, rotary push-in fitting for 4 mm tube on the rear M5 thread.
// Juki-type holder with a Juki 500-series nozzle below. Sizes other than the caliper reading
// are scaled from the photos (+/- 2 mm).
C_MOTOR_S = 28;
C_MOTOR_L = 35.6;                     // measured: body 34 + front boss 1.6
C_MOTOR_BOSS = 1.6;
NOZ_MOTOR_Z = 37;                     // bottom of the motor boss above the nozzle tip
C_REAR_STACK = 39.9;                  // sleeve, hex, bearing, rotary body, fitting, collar
NOZ_TOP = NOZ_MOTOR_Z + C_MOTOR_L + C_REAR_STACK;   // 112.5, top of the push-in fitting above the tip
PUMP_IN = [251, BEAM_Y - 5, 209];     // hose port on the valve, outside the right post

// ---------------------------------------------------------------- paste head
// AFDE 42SH3402Y-200N as photographed: NEMA 17 non-captive linear stepper (lead screw through
// the motor), 34 mm body, 200 mm screw. It pushes the syringe plunger.
PASTE_MOTOR_L = 34;
PASTE_SCREW = [8, 200];               // diameter, length
PASTE_LEVEL = 0.6;                    // share of the barrel still full (model only)

// ---------------------------------------------------------------- colours
C_ALU    = [0.78, 0.80, 0.83];
C_PLATE  = [0.30, 0.33, 0.37];
C_RAIL   = [0.62, 0.64, 0.67];
C_BLOCK  = [0.42, 0.44, 0.47];
C_CAP    = [0.12, 0.12, 0.13];
C_MOTOR  = [0.13, 0.13, 0.14];
C_LAM    = [0.55, 0.56, 0.58];
C_PRINT  = [0.93, 0.45, 0.12];
C_BELT   = [0.08, 0.08, 0.08];
C_BRASS  = [0.80, 0.63, 0.30];
C_PCB    = [0.06, 0.36, 0.18];
C_PAD    = [0.86, 0.72, 0.36];
C_BARREL = [0.88, 0.92, 0.96, 0.45];
C_PASTE  = [0.55, 0.57, 0.58];
C_RUBBER = [0.10, 0.10, 0.10];
C_HOSE   = [0.20, 0.45, 0.85];
C_WHITE  = [0.94, 0.94, 0.92];
C_STEEL  = [0.78, 0.79, 0.80];
C_POM    = [0.10, 0.10, 0.11];
C_ZINC   = [0.66, 0.67, 0.69];
C_JUKI   = [0.15, 0.55, 0.32];

// ---------------------------------------------------------------- pose
function pose() = animate ? [
    lookup($t, [[0, 115], [0.45, 115], [0.55, 20], [0.72, 215], [0.85, 115], [1, 115]]),
    lookup($t, [[0, 100], [0.15, 10], [0.35, 190], [0.45, 100], [1, 100]]),
    lookup($t, [[0, 0], [0.86, 0], [0.89, 25], [0.92, 0], [1, 0]]),
    lookup($t, [[0, 0], [0.93, 0], [0.96, 25], [0.99, 0], [1, 0]]),
    lookup($t, [[0, 0], [0.86, 0], [1, 360]])
  ] : [pose_x, pose_y, pose_z_nozzle, pose_z_paste, pose_c];

assert(BED_D <= Y_TRAVEL, "bed deeper than Y travel: tools cannot reach its full depth");
assert(BED_D/2 + Y_TRAVEL/2 < Y_PULLEY_Y - 21.15, "bed hits the Y motor at the end of travel");
assert(MAIN_W/2 + X_TRAVEL/2 < POST_X - 10, "carriage hits the posts at end of X travel");
assert(Z_TIP_SAFE - Z_TRAVEL < Z_PCB_TOP, "Z travel does not reach the board");
assert(MAIN_FRONT - SK8[2] > ZC_FRONT + ZC_T, "SK8 support reaches into the Z plate");
assert(SCREW_Y - KP08[2] + KP08[3] > ZC_FRONT + ZC_T, "KP08 reaches into the Z plate");
assert(MAIN_Z[0] > Z_TAPE_TOP + 5, "carriage plate too close to the bed");

// =================================================================== helpers
module box(p0, p1) translate(p0) cube([p1[0]-p0[0], p1[1]-p0[1], p1[2]-p0[2]]);

// 20-series slot profile, a x b (multiples of 20), centred
module ext_profile(a, b) {
  difference() {
    offset(r=1.5) offset(delta=-1.5) square([a, b], center=true);
    for (i=[0:a/20-1], s=[-1,1]) translate([-a/2+10+20*i, s*(b/2-3)]) square([6.2, 6.01], center=true);
    for (j=[0:b/20-1], s=[-1,1]) translate([s*(a/2-3), -b/2+10+20*j]) square([6.01, 6.2], center=true);
    for (i=[0:a/20-1], j=[0:b/20-1]) translate([-a/2+10+20*i, -b/2+10+20*j]) circle(d=4.2, $fn=12);
  }
}
module ext_x(len, wy, hz) color(C_ALU) rotate([0,90,0]) linear_extrude(len, center=true) ext_profile(hz, wy);
module ext_y(len, wx, hz) color(C_ALU) rotate([-90,0,0]) linear_extrude(len, center=true) ext_profile(wx, hz);
module ext_z(len, wx, dy) color(C_ALU) linear_extrude(len) ext_profile(wx, dy);

// Linear guide rail along local X, seat at z = 0
module mgn_rail(g, len) {
  WR = g_WR(g); HR = g_HR(g); P = g_P(g);
  color(C_RAIL) difference() {
    translate([-len/2, -WR/2, 0]) cube([len, WR, HR]);
    for (s=[-1,1]) translate([-len/2-1, s*WR/2 - 0.6, HR*0.45]) cube([len+2, 1.2, HR*0.3]);
    for (x=[-len/2+P/2:P:len/2-P/4]) translate([x, 0, HR-2]) cylinder(d=WR*0.5, h=3, $fn=12);
  }
}
// Block on the rail, same local frame as mgn_rail
module mgn_block(g) {
  WR = g_WR(g); HR = g_HR(g); W = g_W(g); L = g_L(g); L1 = g_L1(g); H = g_H(g); H1 = g_H1(g);
  difference() {
    union() {
      color(C_BLOCK) translate([-L1/2, -W/2, H1]) cube([L1, W, H-H1]);
      color(C_CAP) for (s=[-1,1]) translate([s>0 ? L1/2 : -L/2, -W/2+0.6, H1+0.4]) cube([(L-L1)/2, W-1.2, H-H1-1.2]);
    }
    translate([-L, -WR/2-0.2, -1]) cube([2*L, WR+0.4, HR+1+0.2]);
    for (x=[-1,1]*L1*0.3, y=[-1,1]*W*0.37) translate([x, y, H-2]) cylinder(d=2.6, h=3, $fn=10);
  }
}

// NEMA stepper: mounting face at z = 0, body toward -z, shaft toward +z
module stepper(S, len, pilot_d, shaft_d, shaft_l, hollow=0) {
  c = S*0.12;
  module sq() offset(delta=c, chamfer=true) square(S-2*c, center=true);
  cap = min(8, len*0.25);
  color(C_MOTOR) {
    translate([0,0,-cap]) linear_extrude(cap) sq();
    translate([0,0,-len]) linear_extrude(cap) sq();
  }
  color(C_LAM) translate([0,0,-len+cap]) linear_extrude(len-2*cap) offset(delta=-0.3) sq();
  color(C_LAM) difference() {
    union() {
      cylinder(d=pilot_d, h=1.5);
      cylinder(d=shaft_d, h=shaft_l);
    }
    if (hollow > 0) translate([0,0,-1]) cylinder(d=hollow, h=shaft_l+2, $fn=12);
  }
}
module nema17(len=XY_MOTOR_L) stepper(42.3, len, 22, 5, 22);
// NEMA 11 external linear actuator: the ball screw is the motor shaft
module nema11_hollow() stepper(C_MOTOR_S, C_MOTOR_L - C_MOTOR_BOSS, 22, 5, 0.1, hollow=3);
module nema17_linear() stepper(42.3, PASTE_MOTOR_L, 22, PASTE_SCREW[0], 0.1);

// Z drive parts, in the carriage frame: front face of the carriage plate at y = MAIN_FRONT
module kp08(z) color(C_ZINC) translate([0, 0, z]) {
  box([-KP08[0]/2, MAIN_FRONT-5, 0], [KP08[0]/2, MAIN_FRONT, KP08[1]]);
  box([-13, SCREW_Y, 0], [13, MAIN_FRONT, KP08[1]]);
  translate([0, SCREW_Y, 0]) cylinder(d=2*(KP08[2]-KP08[3]), h=KP08[1]);
}
module sk8(z) color(C_ALU) translate([0, 0, z]) {
  box([-SK8[0]/2, MAIN_FRONT-6, 0], [SK8[0]/2, MAIN_FRONT, SK8[1]]);
  box([-SK8[4]/2, MAIN_FRONT-SK8[2], 0], [SK8[4]/2, MAIN_FRONT, SK8[1]]);
}

// GT2 pulley, 20 teeth: pitch diameter 20*2/pi = 12.73 mm, 40 mm per revolution
GT2_PD = 20*2/PI;
module gt2_pulley(w=7, hub=true) {
  color(C_LAM) {
    cylinder(d=GT2_PD, h=w, center=true);
    for (s=[-1,1]) translate([0,0,s*(w/2+0.5)]) cylinder(d=GT2_PD+4, h=1, center=true);
    if (hub) translate([0,0,-w/2-1-6]) cylinder(d=GT2_PD+3, h=6);
  }
}
// Closed belt around two equal pulleys D apart along local X, width along local Z
module belt_loop(D, w=6, t=1.4) {
  r = GT2_PD/2;
  color(C_BELT) linear_extrude(w, center=true) difference() {
    hull() for (x=[-D/2, D/2]) translate([x,0]) circle(r=r+t, $fn=40);
    hull() for (x=[-D/2, D/2]) translate([x,0]) circle(r=r, $fn=40);
  }
}

// =================================================================== frame
module frame() {
  // feet
  color(C_RUBBER) for (sx=[-1,1], sy=[-1,1]) translate([sx*(FRAME_W/2-20), sy*(FRAME_D/2-20), 0]) cylinder(d=24, h=FOOT_H);
  // base rectangle: 2040 on edge
  zc = FOOT_H + BASE_H/2;
  for (s=[-1,1]) translate([0, s*(FRAME_D/2-10), zc]) ext_x(FRAME_W, 20, 40);
  for (s=[-1,1]) translate([s*(FRAME_W/2-10), 0, zc]) ext_y(FRAME_D-40, 20, 40);
  // centre cross member under the gantry
  translate([0, BEAM_Y, zc]) ext_x(FRAME_W-40, 20, 40);
  // base plate
  color(C_PLATE) box([-FRAME_W/2, -FRAME_D/2, Z_BASE_TOP], [FRAME_W/2, FRAME_D/2, Z_PLATE]);
}

// =================================================================== Y axis, fixed part
module y_axis_fixed() {
  for (s=[-1,1]) {
    translate([s*Y_RAIL_X, 0, Z_PLATE + RISER_H/2]) ext_y(Y_RAIL_LEN, 20, 20);
    translate([s*Y_RAIL_X, 0, Z_YRAIL]) rotate([0,0,90]) mgn_rail(MGN12, Y_RAIL_LEN);
  }
  // drive: NEMA 17 at the back, shaft along -X, pulley in the belt plane X = 0
  translate([12, Y_PULLEY_Y, Z_YBELT]) rotate([0,-90,0]) nema17();
  color(C_PRINT) difference() {
    box([8, Y_PULLEY_Y-24, Z_PLATE], [12, Y_PULLEY_Y+22, Z_YBELT+24]);
    translate([7, Y_PULLEY_Y, Z_YBELT]) rotate([0,90,0]) cylinder(d=23, h=6);
  }
  color(C_PRINT) box([-30, Y_PULLEY_Y-24, Z_PLATE], [12, Y_PULLEY_Y+22, Z_PLATE+4]);
  translate([0, Y_PULLEY_Y, Z_YBELT]) rotate([0,-90,0]) gt2_pulley();
  // idler at the front
  translate([0, -Y_PULLEY_Y, Z_YBELT]) rotate([0,90,0]) gt2_pulley(hub=false);
  color(C_PRINT) for (s=[-1,1]) box([s*6-2, -Y_PULLEY_Y-12, Z_PLATE], [s*6+2, -Y_PULLEY_Y+12, Z_YBELT+10]);
  color(C_LAM) translate([-9, -Y_PULLEY_Y, Z_YBELT]) rotate([0,90,0]) cylinder(d=5, h=18);
  // belt loop in the YZ plane
  translate([0, 0, Z_YBELT]) rotate([90,0,90]) belt_loop(2*Y_PULLEY_Y);
}

// =================================================================== bed (moves in Y)
module bed(show_parts=true) {
  // bearing blocks
  for (sx=[-1,1], sy=[-1,1]) translate([sx*Y_RAIL_X, sy*Y_BLOCK_OFF, Z_YRAIL]) rotate([0,0,90]) mgn_block(MGN12);
  // belt clamp
  color(C_PRINT) difference() {
    box([-8, -12, Z_YBELT-1], [8, 12, Z_BED]);
    box([-4, -13, Z_YBELT + GT2_PD/2 - 1], [4, 13, Z_YBELT + GT2_PD/2 + 2.4]);
  }
  // tooling plate
  color(C_PLATE) difference() {
    box([-BED_W/2, -BED_D/2, Z_BED], [BED_W/2, BED_D/2, Z_BED_TOP]);
    for (x=[-60:20:60], y=[-80:20:80]) translate([x, y, Z_BED_TOP-1.5]) cylinder(d=3, h=2, $fn=8);
  }
  // PCB fixture: 1.4 mm floor + 1.6 mm frame, board sits flush at Z_PCB_TOP
  translate([PCB_C[0], PCB_C[1], 0]) {
    color(C_PRINT) difference() {
      box([-PCB_W/2-FIX_RIM, -PCB_D/2-FIX_RIM, Z_BED_TOP], [PCB_W/2+FIX_RIM, PCB_D/2+FIX_RIM, Z_PCB_TOP]);
      box([-PCB_W/2-0.2, -PCB_D/2-0.2, Z_PCB_TOP-PCB_T], [PCB_W/2+0.2, PCB_D/2+0.2, Z_PCB_TOP+1]);
    }
    pcb(show_parts);
  }
  // strip feeders for 8 mm tape, across the back half of the bed
  for (i=[0:FEEDER_N-1]) translate([0, FEEDER_Y0 + i*FEEDER_PITCH, 0]) strip_feeder(i);
}

// Footprints on the demo board (board-local X, Y, rotation, type)
// Types: 0 = 0805 R, 1 = 0805 C, 2 = SOT-23, 3 = 0603 LED
BOARD_PARTS = [
  [-30, 20, 0, 0], [-30, 8, 0, 0], [-30, -4, 0, 1], [-10, 20, 90, 1],
  [8, 18, 0, 2], [8, -2, 180, 2], [28, 18, 0, 3], [28, 6, 0, 3],
  [-30, -22, 0, 0], [-10, -22, 90, 1], [12, -22, 0, 0], [30, -22, 0, 1]
];
PART_DIMS = [[2.0, 1.25, 0.5], [2.0, 1.25, 1.25], [2.9, 1.3, 1.0], [1.6, 0.8, 0.6]];
PART_COL  = [[0.10, 0.10, 0.10], [0.70, 0.60, 0.45], [0.12, 0.12, 0.12], [0.92, 0.92, 0.88]];

module pads(type) {
  if (type == 2) { // SOT-23
    for (p=[[-0.95, -1.1], [0.95, -1.1], [0, 1.1]]) translate([p[0], p[1], 0]) square([0.9, 0.8], center=true);
  } else {
    d = PART_DIMS[type][0];
    for (s=[-1,1]) translate([s*d*0.5, 0]) square([d*0.45, PART_DIMS[type][1]*1.1], center=true);
  }
}
module pcb(show_parts=true) {
  color(C_PCB) box([-PCB_W/2, -PCB_D/2, Z_PCB_TOP-PCB_T], [PCB_W/2, PCB_D/2, Z_PCB_TOP-0.02]);
  // fiducials and pads
  color(C_PAD) translate([0, 0, Z_PCB_TOP-0.03]) linear_extrude(0.05) {
    for (p=[[-45, -35], [45, 35], [-45, 35]]) translate(p) circle(d=1.0, $fn=16);
    for (p=BOARD_PARTS) translate([p[0], p[1]]) rotate(p[2]) pads(p[3]);
  }
  if (show_parts) for (p=BOARD_PARTS) translate([p[0], p[1], Z_PCB_TOP]) rotate(p[2]) {
    color(PART_COL[p[3]]) translate([0, 0, 0.05 + PART_DIMS[p[3]][2]/2]) cube(PART_DIMS[p[3]], center=true);
  }
}

// One strip along X. Built with the tape along local Y, then turned so local Y = world X,
// local X = world -Y (sprocket holes toward the back, pockets toward the front).
module strip_feeder(i) {
  type = i % 4;
  len = FEEDER_X[1] - FEEDER_X[0];
  xc = (FEEDER_X[0] + FEEDER_X[1]) / 2;
  translate([xc, 0, 0]) rotate([0, 0, -90]) {
    color(C_PRINT) difference() {
      box([-6, -len/2, Z_BED_TOP], [6, len/2, Z_TAPE_TOP-0.6]);
      box([-4.2, -len/2-1, Z_TAPE_TOP-1.6], [4.2, len/2+1, Z_TAPE_TOP]);
    }
    // carrier tape: pocket floor plus the sprocket-side and far-side rims
    color([0.20, 0.20, 0.22]) {
      box([-4, -len/2, Z_TAPE_TOP-1.6], [4, len/2, Z_TAPE_TOP-1.3]);
      box([-4, -len/2, Z_TAPE_TOP-1.6], [-1.2, len/2, Z_TAPE_TOP-0.1]);
      box([3.4, -len/2, Z_TAPE_TOP-1.6], [4, len/2, Z_TAPE_TOP-0.1]);
    }
    // cover tape, peeled back from the pick end (left)
    color([0.92, 0.92, 0.90, 0.5]) box([-1.2, -len/2 + 30, Z_TAPE_TOP-0.1], [3.4, len/2, Z_TAPE_TOP]);
    // sprocket holes (1.5 mm on 4 mm pitch) and parts in the pockets
    for (k=[0:floor(len/TAPE_POCKET_PITCH)-1]) {
      y = -len/2 + 2 + k*TAPE_POCKET_PITCH;
      color([0.05,0.05,0.05]) translate([-2.25, y, Z_TAPE_TOP-0.12]) cylinder(d=1.5, h=0.1, $fn=10);
      // long axis across the tape
      color(PART_COL[type]) translate([-TAPE_PART_OFF, y, Z_TAPE_TOP-0.05-PART_DIMS[type][2]/2])
        cube([PART_DIMS[type][0], PART_DIMS[type][1], PART_DIMS[type][2]], center=true);
    }
  }
}

// =================================================================== gantry, fixed part
module gantry_fixed() {
  // posts: 2040 standing on the base plate, 40 deep in Y
  for (s=[-1,1]) translate([s*POST_X, BEAM_Y, Z_PLATE]) ext_z(Z_POST_TOP - Z_PLATE, 20, 40);
  // beam: 2040, 40 tall
  translate([0, BEAM_Y, Z_BEAM]) ext_x(FRAME_W, 20, 40);
  // printed gussets on the inner face of each post, at the plate and under the beam
  color(C_PRINT) for (s=[-1,1]) {
    xi = s*(POST_X-10);
    translate([0, BEAM_Y, 0]) rotate([90,0,0]) linear_extrude(4, center=true) {
      polygon([[xi, Z_PLATE], [xi, Z_PLATE+40], [xi - s*40, Z_PLATE]]);
      polygon([[xi, Z_POST_TOP], [xi, Z_POST_TOP-40], [xi - s*40, Z_POST_TOP]]);
    }
  }
  // X rail on the beam front face
  translate([0, XRAIL_SEAT, Z_BEAM]) rotate([90,0,0]) mgn_rail(MGN12, 400);
  // X drive: NEMA 17 hanging below a bracket at the right end, idler at the left end
  for (s=[-1,1]) color(C_PRINT) box([s>0 ? POST_X-10 : -X_PULLEY_X-26, BEAM_Y-22, Z_BEAM+20], [s>0 ? X_PULLEY_X+26 : -POST_X+10, BEAM_Y+22, Z_BEAM+24]);
  translate([X_PULLEY_X, BEAM_Y, Z_BEAM+20]) rotate([0,0,0]) nema17();
  translate([X_PULLEY_X, BEAM_Y, Z_XBELT]) gt2_pulley();
  translate([-X_PULLEY_X, BEAM_Y, Z_XBELT]) gt2_pulley(hub=false);
  color(C_LAM) translate([-X_PULLEY_X, BEAM_Y, Z_BEAM+24]) cylinder(d=5, h=Z_XBELT-Z_BEAM-24+5);
  translate([0, BEAM_Y, Z_XBELT]) belt_loop(2*X_PULLEY_X);
}

// =================================================================== fixed stations
module stations() {
  // up-looking camera for part alignment
  translate([BOTTOM_CAM_X, TOOL_Y, 0]) {
    color(C_PRINT) box([-22, -22, Z_PLATE], [22, 22, Z_PLATE+8]);
    color([0.05, 0.25, 0.12]) box([-19, -19, Z_PLATE+8], [19, 19, Z_PLATE+18]);
    color(C_CAP) translate([0,0,Z_PLATE+18]) cylinder(d=14, h=12);
    color([0.9, 0.9, 0.95]) translate([0,0,Z_PLATE+26]) difference() {
      cylinder(d=50, h=4, $fn=48);
      translate([0,0,-1]) cylinder(d=20, h=6);
    }
  }
  // syringe purge / wipe cup
  translate([PURGE_X, TOOL_Y, Z_PLATE]) {
    color(C_PRINT) difference() { cylinder(d=34, h=30); translate([0,0,3]) cylinder(d=30, h=30); }
    color([0.95, 0.85, 0.25]) translate([0,0,22]) cylinder(d=30, h=6);
  }
  // reject bin for parts that fail the bottom-camera check
  translate([REJECT_X, TOOL_Y, Z_PLATE]) color(C_PRINT) difference() {
    box([-15, -20, 0], [15, 20, 26]);
    box([-13, -18, 2], [13, 18, 27]);
  }
  // controller behind the bed travel
  color([0.18, 0.19, 0.21]) box([-200, 200, Z_PLATE], [-60, 236, Z_PLATE+60]);
  color([0.25, 0.45, 0.75]) box([-190, 199, Z_PLATE+42], [-150, 200, Z_PLATE+52]);
  // vacuum pump and solenoid valve on the outside of the right post
  color(C_PRINT) box([POST_X+10, BEAM_Y-20, 125], [POST_X+13, BEAM_Y+20, 195]);
  color([0.20, 0.21, 0.23]) box([POST_X+13, BEAM_Y-23, 130], [POST_X+49, BEAM_Y+23, 190]);
  color(C_CAP) box([PUMP_IN[0]-11, PUMP_IN[1]-7, 190], [PUMP_IN[0]+11, PUMP_IN[1]+11, 204]);
  color(C_BRASS) translate([PUMP_IN[0], PUMP_IN[1], 204]) cylinder(d=6, h=PUMP_IN[2]-204);
}

// =================================================================== X carriage (moves in X)
module x_carriage(z1, z2, c) {
  // X bearing block on the beam rail
  translate([0, XRAIL_SEAT, Z_BEAM]) rotate([90,0,0]) mgn_block(MGN12);
  // main plate
  color(C_PLATE) box([-MAIN_W/2, MAIN_FRONT, MAIN_Z[0]], [MAIN_W/2, MAIN_FRONT+MAIN_T, MAIN_Z[1]]);
  // belt clamp reaching back over the beam to the front run of the X belt
  color(C_PRINT) box([-12, MAIN_FRONT+MAIN_T, MAIN_Z[1]+2], [12, BEAM_Y - GT2_PD/2 + 3, Z_XBELT+7]);
  // motor shelf
  color(C_PRINT) box([-MAIN_W/2, ZC_FRONT, MAIN_Z[1]], [MAIN_W/2, MAIN_FRONT+MAIN_T, MAIN_Z[1]+4]);
  // Z drive and guide for each head; s = +1 nozzle (right), -1 syringe (left), rods on the outer sides
  for (s=[-1,1]) translate([s*TOOL_DX, 0, 0]) {
    kp08(KP08_BOT_Z);
    kp08(KP08_TOP_Z);
    color(C_STEEL) translate([0, SCREW_Y, SCREW_Z[0]]) cylinder(d=8, h=SCREW_Z[1]-SCREW_Z[0]);
    color(C_ALU) translate([0, SCREW_Y, COUPLER_Z]) cylinder(d=COUPLER[0], h=COUPLER[1]);
    translate([0, SCREW_Y, MAIN_Z[1]+4]) rotate([180,0,0]) nema17(Z_MOTOR_L);
    translate([s*ROD_DX, 0, 0]) {
      sk8(SK8_BOT_Z);
      sk8(SK8_TOP_Z);
      color(C_STEEL) translate([0, ROD_Y, ROD_Z[0]]) cylinder(d=8, h=ROD_Z[1]-ROD_Z[0]);
    }
  }
  // top (down-looking) camera between the tools
  color(C_PRINT) box([-10, 15, 160], [10, MAIN_FRONT, 172]);
  color([0.05, 0.25, 0.12]) box([-15, -15, 150], [15, 15, 175]);
  color(C_CAP) translate([0, 0, 140]) cylinder(d=12, h=10);
  color([0.9, 0.9, 0.95]) translate([0, 0, 138]) difference() { cylinder(d=30, h=3); translate([0,0,-1]) cylinder(d=16, h=5); }
  // tools
  translate([TOOL_DX, TOOL_Y, Z_TIP_SAFE - z1]) { z_stage(1); nozzle_head(c); }
  translate([-TOOL_DX, TOOL_Y, Z_TIP_SAFE - z2]) { z_stage(-1); syringe(); }
}

// Z plate for one tool, local origin at the tool tip; s = side of the guide rod
module z_stage(s) {
  zb = ZC_FRONT + ZC_T;               // back face of the Z plate
  xr = s*ROD_DX;
  color(C_PLATE) box([s>0 ? -20 : -ROD_DX-19, ZC_FRONT, ZP_Z[0]], [s>0 ? ROD_DX+19 : 20, zb, ZP_Z[1]]);
  // anti-backlash nut block on two spacers
  color(C_ALU) for (x=[-10, 10]) translate([x, zb, NUT_Z0 + NUT_BLK[1]/2]) rotate([-90,0,0]) cylinder(d=8, h=NUT_SPACER);
  color(C_POM) difference() {
    box([-NUT_BLK[0]/2, SCREW_Y - NUT_BLK[2]/2, NUT_Z0], [NUT_BLK[0]/2, SCREW_Y + NUT_BLK[2]/2, NUT_Z0 + NUT_BLK[1]]);
    box([-NUT_BLK[0]/2 - 1, SCREW_Y - NUT_BLK[2]/2 - 1, NUT_Z0 + 8], [NUT_BLK[0]/2 - 8, SCREW_Y + NUT_BLK[2]/2 + 1, NUT_Z0 + 10]);
    translate([0, SCREW_Y, NUT_Z0 - 1]) cylinder(d=8, h=NUT_BLK[1] + 2);
  }
  // SCS8UU on a spacer, riding on the guide rod
  color(C_ALU) box([xr - SCS8UU[0]/2, zb, SCS_Z0], [xr + SCS8UU[0]/2, zb + SCS_SPACER, SCS_Z0 + SCS8UU[1]]);
  color(C_ZINC) difference() {
    box([xr - SCS8UU[0]/2, zb + SCS_SPACER, SCS_Z0], [xr + SCS8UU[0]/2, zb + SCS_SPACER + SCS8UU[2], SCS_Z0 + SCS8UU[1]]);
    translate([xr, ROD_Y, SCS_Z0 - 1]) cylinder(d=8.2, h=SCS8UU[1] + 2);
  }
}

// Vacuum nozzle head: NEMA 11 hollow-shaft motor turns the nozzle (C axis).
// Vacuum enters through the rotary push-in fitting on top and runs down the hollow shaft.
module nozzle_head(c) {
  z0 = NOZ_MOTOR_Z + C_MOTOR_BOSS;    // motor mounting face
  zt = NOZ_MOTOR_Z + C_MOTOR_L;       // motor rear face
  color(C_PRINT) difference() {
    union() {
      box([-17, -16, z0-4], [17, ZC_FRONT, z0]);
      box([-17, ZC_FRONT-4, z0-4], [17, ZC_FRONT, zt]);
    }
    translate([0,0,z0-5]) cylinder(d=23, h=6);
  }
  translate([0, 0, z0]) rotate([180,0,0]) nema11_hollow();
  // rear stack, scaled from the photo against the 35.6 mm caliper reading
  color(C_STEEL) {
    translate([0,0,zt]) cylinder(d=6, h=2);
    translate([0,0,zt+2]) cylinder(d=8/cos(30), h=5.7, $fn=6);
    translate([0,0,zt+7.7]) cylinder(d=11, h=4);
  }
  color(C_WHITE) {
    translate([0,0,zt+11.7]) cylinder(d=11, h=13.8);
    translate([0,0,zt+25.5]) cylinder(d=9.8, h=9.8);
  }
  color(C_HOSE) translate([0,0,zt+35.3]) cylinder(d=10.3, h=C_REAR_STACK-35.3);
  // rotating part: Juki-type holder and Juki 500-series nozzle
  rotate([0,0,c]) {
    color(C_BRASS) translate([0,0,27.5]) cylinder(d=9, h=NOZ_MOTOR_Z-27.5);
    color(C_JUKI) translate([0,0,25.5]) cylinder(d=12, h=2);
    color(C_BRASS) translate([0,0,18.5]) cylinder(d=8, h=7);
    color(C_JUKI) difference() { translate([0,0,12]) cylinder(d=15, h=6.5); translate([5.5,-1,17.5]) cube([3,2,2]); }
    color(C_STEEL) translate([0,0,6.5]) cylinder(d=4.5, h=5.5);
    color(C_CAP) cylinder(d1=0.7, d2=3.5, h=6.5, $fn=16);
  }
}

// Paste head: 10 cc barrel and luer needle. The plunger is pushed by the NEMA 17 non-captive
// linear stepper standing on a bracket above the barrel; its screw passes through the motor.
module syringe() {
  piston = 21 + 85*PASTE_LEVEL;
  color(C_LAM) cylinder(d=0.8, h=13, $fn=10);
  color([0.20, 0.45, 0.85]) translate([0,0,13]) cylinder(d1=3, d2=6, h=7);
  color(C_PASTE) translate([0,0,21]) cylinder(d=17, h=piston-21);
  color(C_WHITE) translate([0,0,piston]) cylinder(d=17, h=4);
  color(C_BARREL) difference() { translate([0,0,20]) cylinder(d=19, h=90, $fn=40); translate([0,0,21]) cylinder(d=17.2, h=90, $fn=40); }
  color(C_BARREL) translate([-15, -10, 110]) cube([30, 20, 2]);
  // pusher disc and the motor's lead screw
  color(C_STEEL) {
    translate([0,0,piston+4]) cylinder(d=12, h=3);
    translate([0,0,piston+7]) cylinder(d=PASTE_SCREW[0], h=PASTE_SCREW[1]);
  }
  // bracket: back plate on the Z plate, shelf under the motor
  color(C_PRINT) difference() {
    union() {
      box([-22, ZC_FRONT-4, 40], [22, ZC_FRONT, 122]);
      box([-22, -22, 118], [22, ZC_FRONT, 122]);
    }
    translate([0,0,117]) cylinder(d=23, h=6);
  }
  translate([0, 0, 122]) rotate([180,0,0]) nema17_linear();
  // barrel clamps
  color(C_PRINT) for (z=[40, 95]) {
    translate([0,0,z]) difference() { cylinder(d=25, h=6); translate([0,0,-1]) cylinder(d=19.2, h=8); }
    box([-6, 9, z], [6, ZC_FRONT-4, z+6]);
  }
}

// =================================================================== vacuum hose
// Catmull-Rom curve through the control points, drawn as hulled spheres.
function cr(p0, p1, p2, p3, t) =
  0.5 * (2*p1 + (p2 - p0)*t + (2*p0 - 5*p1 + 4*p2 - p3)*t*t + (3*p1 - p0 - 3*p2 + p3)*t*t*t);
function cr_path(P, n=8) = let(m = len(P), Q = concat([P[0]], P, [P[m-1]]))
  concat([for (i=[0:m-2], k=[0:n-1]) cr(Q[i], Q[i+1], Q[i+2], Q[i+3], k/n)], [P[m-1]]);
// From the fitting on top of the nozzle, forward and up past the Z motors, over the
// gantry, down the outside of the right post to the valve on the pump.
function hose_points(xn, ztop) = [
  [xn, 0, ztop], [xn, 0, ztop + 12], [xn, -20, ztop + 60], [xn, -24, 345],
  [xn + (292 - xn)*0.45, 10, 420], [292, BEAM_Y - 20, 355], [292, BEAM_Y - 8, 262],
  [276, PUMP_IN[1] - 1, 228], PUMP_IN + [0, 0, 6], PUMP_IN
];
module hose(P, d=4) {
  S = cr_path(P);
  color(C_HOSE) for (i=[0:len(S)-2]) hull() { translate(S[i]) sphere(d=d, $fn=8); translate(S[i+1]) sphere(d=d, $fn=8); }
}

// =================================================================== assembly
module envelope() {
  // area the tool line sweeps over the bed; drawn in bed-local coordinates at the board height
  color([0.2, 0.5, 1.0, 0.18]) box([-BED_W/2, -Y_TRAVEL/2, Z_PCB_TOP], [BED_W/2, Y_TRAVEL/2, Z_PCB_TOP + 25]);
}

module pnp_200(p) {
  xc = p[0] - X_TRAVEL/2;
  yb = p[1] - Y_TRAVEL/2;
  frame();
  y_axis_fixed();
  gantry_fixed();
  stations();
  translate([0, yb, 0]) bed(show_parts_on_board);
  translate([xc, 0, 0]) x_carriage(p[2], p[3], p[4]);
  hose(hose_points(xc + TOOL_DX, Z_TIP_SAFE - p[2] + NOZ_TOP));
  if (show_envelope) envelope();
}

P = pose();
echo(str("PnP-200 pose X=", P[0], " Y=", P[1], " Z1=", P[2], " Z2=", P[3], " C=", P[4]));
echo(str("Frame ", FRAME_W, " x ", FRAME_D, " mm (", 2*(X_PULLEY_X+26), " mm wide over the X drive, ", POST_X+49, " mm to the pump side), top of Z motors at ", MAIN_Z[1]+4+Z_MOTOR_L, " mm"));
echo(str("Z stack: KP08 at ", KP08_BOT_Z, " and ", KP08_TOP_Z, ", SK8 at ", SK8_BOT_Z, " and ", SK8_TOP_Z, ", T8 screw ", SCREW_Z[1]-SCREW_Z[0], " mm, rod ", ROD_Z[1]-ROD_Z[0], " mm, nut spacer ", NUT_SPACER, " mm"));
echo(str("Bed ", BED_W, " x ", BED_D, " mm, board fixture ", PCB_W, " x ", PCB_D, " mm"));
echo(str("X/Y: 0.9 deg motor, GT2 20T = ", 20*2, " mm/rev: ", 20*2/400, " mm per full step, ", 400*16/(20*2), " microsteps/mm at 1/16"));
echo(str("Z: 0.9 deg motor, Tr8 lead ", T8_LEAD, " mm: ", T8_LEAD/400, " mm per full step, ", 400*16/T8_LEAD, " microsteps/mm at 1/16"));
pnp_200(P);
