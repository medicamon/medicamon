// PnP-200: desktop pick-and-place machine with solder-paste dispenser
// Concept assembly, parametric.
//
// Kinematics
//   Y  bed (board plane) moves front/back, 200 mm travel
//   X  tool carriage moves left/right on a fixed gantry, 280 mm travel
//   Z1 vacuum nozzle up/down, 40 mm, plus C rotation (hollow-shaft NEMA 11)
//   Z2 paste syringe up/down, 40 mm
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
pose_x = 140; // [0:1:280]
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
X_TRAVEL = 280;
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
Y_RAIL_LEN = 400;
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
ZC_FRONT = 26;                        // Z carriage plate front face
ZC_T = 5;
MAIN_FRONT = ZC_FRONT + ZC_T + g_H(MGN9);   // 41, main carriage plate front face
MAIN_T = 8;
XRAIL_SEAT = MAIN_FRONT + MAIN_T + g_H(MGN12); // 62, beam front face
BEAM_Y = XRAIL_SEAT + 10;             // 72, beam centre (20 deep)
Z_BEAM = 280;                         // beam centre (40 tall)
Z_POST_TOP = Z_BEAM - 20;             // 260
MAIN_W = 120;
MAIN_Z = [130, 330];
TOOL_DX = 35;                         // nozzle at +35, syringe at -35
Z_TIP_SAFE = 121;                     // tool tip height at Z = 0
Z_RAIL_Z = [140, 310];
SCREW_Y = 21;
X_PULLEY_X = 255;                     // clear of the beam end (230) by the motor half-width
Z_XBELT = 315;

// ---------------------------------------------------------------- fixed stations on the tool line
BOTTOM_CAM_X = 160;
PURGE_X = -160;
REJECT_X = 110;

// ---------------------------------------------------------------- nozzle head (C axis)
// OUKEDA OK28ZK34-084B-HM5 as photographed: 28 mm frame, 34 mm body, hollow shaft,
// rotary push-in fitting for 4 mm tube on the rear M5 thread. Stack sizes above the
// motor are estimated from the photo.
C_MOTOR_S = 28;
C_MOTOR_L = 34;
NOZ_MOTOR_Z = 31;                     // motor face (down) above the nozzle tip
NOZ_TOP = NOZ_MOTOR_Z + C_MOTOR_L + 37;   // 102, top of the push-in fitting above the tip
PUMP_IN = [251, 67, 209];             // hose port on the valve, outside the right post

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

// ---------------------------------------------------------------- pose
function pose() = animate ? [
    lookup($t, [[0, 140], [0.45, 140], [0.55, 30], [0.72, 265], [0.85, 140], [1, 140]]),
    lookup($t, [[0, 100], [0.15, 10], [0.35, 190], [0.45, 100], [1, 100]]),
    lookup($t, [[0, 0], [0.86, 0], [0.89, 25], [0.92, 0], [1, 0]]),
    lookup($t, [[0, 0], [0.93, 0], [0.96, 25], [0.99, 0], [1, 0]]),
    lookup($t, [[0, 0], [0.86, 0], [1, 360]])
  ] : [pose_x, pose_y, pose_z_nozzle, pose_z_paste, pose_c];

assert(BED_D <= Y_TRAVEL, "bed deeper than Y travel: tools cannot reach its full depth");
assert(BED_D/2 + Y_TRAVEL/2 < Y_PULLEY_Y - 21.15, "bed hits the Y motor at the end of travel");
assert(MAIN_W/2 + X_TRAVEL/2 < POST_X - 10, "carriage hits the posts at end of X travel");
assert(Z_TIP_SAFE - Z_TRAVEL < Z_PCB_TOP, "Z travel does not reach the board");

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
module nema17(len=40) stepper(42.3, len, 22, 5, 22);
module nema11(len=32) stepper(28, len, 22, 5, 20);
module nema11_hollow(len=C_MOTOR_L) stepper(C_MOTOR_S, len, 22, 5, 0.1, hollow=3);

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
  color(C_PRINT) {
    box([-12, MAIN_FRONT+MAIN_T, MAIN_Z[1]-10], [12, BEAM_Y - GT2_PD/2 + 3, MAIN_Z[1]]);
    box([-12, BEAM_Y - GT2_PD/2 - 6, Z_XBELT-5], [12, BEAM_Y - GT2_PD/2 + 3, MAIN_Z[1]]);
  }
  // motor shelf
  color(C_PRINT) box([-MAIN_W/2, -12, MAIN_Z[1]], [MAIN_W/2, MAIN_FRONT+MAIN_T, MAIN_Z[1]+4]);
  // Z rails, lead screws and Z motors
  for (s=[-1,1]) translate([s*TOOL_DX, 0, 0]) {
    translate([0, MAIN_FRONT, (Z_RAIL_Z[0]+Z_RAIL_Z[1])/2]) rotate([0,0,90]) rotate([0,-90,0]) mgn_rail(MGN9, Z_RAIL_Z[1]-Z_RAIL_Z[0]);
    translate([0, SCREW_Y, MAIN_Z[1]+4]) rotate([180,0,0]) nema11();
    color(C_LAM) translate([0, SCREW_Y, 200]) cylinder(d=8, h=MAIN_Z[1]-200-18);
    color(C_LAM) translate([0, SCREW_Y, MAIN_Z[1]-18]) cylinder(d=14, h=18);
  }
  // top (down-looking) camera between the tools
  color(C_PRINT) box([-10, 15, 160], [10, MAIN_FRONT, 172]);
  color([0.05, 0.25, 0.12]) box([-15, -15, 150], [15, 15, 175]);
  color(C_CAP) translate([0, 0, 140]) cylinder(d=12, h=10);
  color([0.9, 0.9, 0.95]) translate([0, 0, 138]) difference() { cylinder(d=30, h=3); translate([0,0,-1]) cylinder(d=16, h=5); }
  // tools
  translate([TOOL_DX, TOOL_Y, Z_TIP_SAFE - z1]) { z_stage(); nozzle_head(c); }
  translate([-TOOL_DX, TOOL_Y, Z_TIP_SAFE - z2]) { z_stage(); syringe(); }
}

// Z carriage for one tool, local origin at the tool tip
module z_stage() {
  // MGN9 block, its rail seat is the main plate front face
  translate([0, MAIN_FRONT, 85]) rotate([0,0,90]) rotate([0,-90,0]) mgn_block(MGN9);
  color(C_PLATE) box([-15, ZC_FRONT, 25], [15, ZC_FRONT+ZC_T, 140]);
  // lead screw nut
  color(C_BRASS) box([-8, 14, 128], [8, ZC_FRONT, 140]);
}

// Vacuum nozzle head: NEMA 11 hollow-shaft motor turns the nozzle (C axis).
// Vacuum enters through the rotary push-in fitting on top and runs down the hollow shaft.
module nozzle_head(c) {
  z0 = NOZ_MOTOR_Z;
  color(C_PRINT) difference() {
    union() {
      box([-17, -16, z0-4], [17, ZC_FRONT, z0]);
      box([-17, ZC_FRONT-4, z0-4], [17, ZC_FRONT, z0+C_MOTOR_L]);
    }
    translate([0,0,z0-5]) cylinder(d=23, h=6);
  }
  translate([0, 0, z0]) rotate([180,0,0]) nema11_hollow();
  // rear stack, estimated from the photo: shaft sleeve, M5 hex, bearing, rotary body, push-in fitting, release collar
  zt = z0 + C_MOTOR_L;
  color(C_STEEL) {
    translate([0,0,zt]) cylinder(d=6, h=6);
    translate([0,0,zt+6]) cylinder(d=8/cos(30), h=5, $fn=6);
    translate([0,0,zt+11]) cylinder(d=11, h=3);
  }
  color(C_WHITE) {
    translate([0,0,zt+14]) cylinder(d=12, h=11);
    translate([0,0,zt+25]) cylinder(d=8.5, h=7);
  }
  color(C_HOSE) translate([0,0,zt+32]) cylinder(d=10, h=5);
  // rotating part: Juki-style holder on the 5 mm front shaft + nozzle
  rotate([0,0,c]) {
    color(C_LAM) translate([0,0,z0-3]) cylinder(d=5, h=3);
    color(C_LAM) difference() { translate([0,0,16]) cylinder(d=10, h=11); translate([3.6,-6,15]) cube([4,12,13]); }
    color(C_CAP) translate([0,0,9]) cylinder(d=5, h=7);
    color(C_LAM) translate([0,0,5]) cylinder(d1=1.6, d2=5, h=4);
    color(C_LAM) cylinder(d=1.0, h=5, $fn=12);
  }
}

// Paste syringe: 10 cc barrel on a pneumatic adapter, luer-lock needle
module syringe() {
  color(C_LAM) cylinder(d=0.8, h=13, $fn=10);
  color([0.20, 0.45, 0.85]) translate([0,0,13]) cylinder(d1=3, d2=6, h=7);
  color(C_PASTE) translate([0,0,21]) cylinder(d=17, h=59);
  color([0.95,0.95,0.95]) translate([0,0,80]) cylinder(d=17, h=4);
  color(C_BARREL) difference() { translate([0,0,20]) cylinder(d=19, h=90, $fn=40); translate([0,0,21]) cylinder(d=17.2, h=90, $fn=40); }
  color(C_BARREL) translate([-15, -10, 110]) cube([30, 20, 2]);
  color([0.20, 0.22, 0.25]) translate([0,0,112]) cylinder(d=22, h=14);
  color([0.85, 0.85, 0.80, 0.8]) translate([0,0,126]) cylinder(d=5, h=10);
  // clamps to the Z carriage
  color(C_PRINT) for (z=[40, 95]) {
    translate([0,0,z]) difference() { cylinder(d=25, h=6); translate([0,0,-1]) cylinder(d=19.2, h=8); }
    box([-6, 12, z], [6, ZC_FRONT, z+6]);
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
echo(str("Frame ", FRAME_W, " x ", FRAME_D, " mm (", 2*(X_PULLEY_X+26), " mm wide over the X drive, ", POST_X+49, " mm to the pump side), top of Z motors at ", MAIN_Z[1]+4+32, " mm"));
echo(str("Bed ", BED_W, " x ", BED_D, " mm, board fixture ", PCB_W, " x ", PCB_D, " mm"));
echo(str("X/Y belt: GT2 20T, ", 20*2, " mm/rev, ", 200*16/(20*2), " microsteps/mm at 1/16"));
pnp_200(P);
