// sim_test.cpp: runs axis_core.h against a simulated belt axis.
//
// The plant has the errors a glass scale is meant to remove: an off-centre
// pulley, belt stretch, carriage friction, microstep error and lost motion
// at the rotor. Step timing copies the AVR Timer1 code in scale_axis.ino.
//
//   g++ -std=c++11 -O2 -Wall -Wextra -I.. sim_test.cpp -o sim_test && ./sim_test
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <random>
#include <string>
#include <vector>

#include "axis_core.h"

static int failures = 0;
#define CHECK(cond, ...)                                  \
  do {                                                    \
    if (!(cond)) {                                        \
      ++failures;                                         \
      printf("  FAIL %s:%d: ", __FILE__, __LINE__);       \
      printf(__VA_ARGS__);                                \
      printf("\n");                                       \
    }                                                     \
  } while (0)

static const double PI = 3.14159265358979;

// ---- the simulated axis ------------------------------------------------------

struct Plant {
  // mechanics
  double spm = 160;          // steps per mm at the belt
  double msAmp = 0.005;      // microstep position error, mm
  double lostMotion = 0.003; // rotor dead zone, mm
  double ecc = 0.025;        // pulley eccentricity, mm
  double circ = 40;          // belt travel per pulley turn, mm
  double mass = 2.0;         // kg
  double k = 70.0;           // belt stiffness, N/mm (about 30 Hz with 2 kg)
  double zeta = 0.05;
  double fric = 1.0;         // carriage friction, N
  // scale
  double mmPerCount = 0.005;
  double scaleSlope = 20e-6; // the scale reads 20 ppm long
  double scaleZero = 0.0021;
  double refFirst = 3.217, refPitch = 50;
  // home switch
  double swPos = -1.0, swJitter = 0.005;

  // state
  int32_t steps = 0;
  double rotor = 0, x = 0, v = 0, beltOffset = 0, swNow = -1.0, pushN = 0;
  bool stalled = false, enabled = false, swLatched = false;
  int32_t decoded = 0;
  uint8_t encState = 0;
  uint16_t decErrors = 0;
  int8_t decDir = 0;
  bool refArmed = false, refSeen = false;
  int32_t refCount = 0;
  std::mt19937 rng{12345};

  // Timer1 emulation, times in 0.5 us ticks
  int64_t tNow = 0, nextEvt = 0;
  bool running = false;
  uint16_t first = 0;
  uint8_t chunks = 0, left = 0;
  int sign = 1;

  void reset(double x0) {
    rotor = x0;
    x = beltPos(x0);  // carriage at rest on the belt
    v = 0;
    steps = 0;
    stepOrigin = x0;
    encState = stateOf(trueCount());
    decoded = 0;
    redrawSwitch();
  }

  double stepOrigin = 0;
  double beltPos(double r) const { return r + ecc * sin(2 * PI * r / circ) + beltOffset; }
  double scaleX(double xx) const { return xx * (1 + scaleSlope) + scaleZero; }
  int32_t trueCount() const { return (int32_t)floor(scaleX(x) / mmPerCount); }
  static uint8_t stateOf(int32_t c) {
    static const uint8_t seq[4] = {0, 1, 3, 2};
    return seq[((c % 4) + 4) % 4];
  }
  void redrawSwitch() {
    std::uniform_real_distribution<double> u(-swJitter, swJitter);
    swNow = swPos + u(rng);
  }
  bool switchActive() {
    if (x < swNow) swLatched = true;
    if (swLatched && x > swNow + 0.5) {
      swLatched = false;
      redrawSwitch();
    }
    return x < swNow;
  }

  void setRate(float sps) {  // same arithmetic as AvrHal::setStepRate
    const float a = fabsf(sps);
    if (a < 1.0f) {
      running = false;
      return;
    }
    const float t = 2000000.0f / a;
    const uint32_t period = t < 50 ? 50 : (uint32_t)t;
    if (period <= 0x7000) {
      first = period;
      chunks = 0;
    } else {
      chunks = (period - 0x2000) >> 14;
      first = period - ((uint32_t)chunks << 14);
    }
    sign = sps < 0 ? -1 : 1;
    if (!running) {
      left = chunks;
      nextEvt = tNow + first;
      running = true;
    }
  }

  void step() {
    steps += sign;
    if (!enabled || stalled) {  // lost step: the rotor stays where it is
      stepOrigin -= sign / spm;
      return;
    }
    const double ideal = stepOrigin + steps / spm + msAmp * sin(2 * PI * steps / 64.0);
    if (ideal - rotor > lostMotion) rotor = ideal - lostMotion;
    else if (rotor - ideal > lostMotion) rotor = ideal + lostMotion;
  }

  // One millisecond in 10 us substeps.
  void runMs() {
    const double dt = 10e-6;
    const double kSI = k * 1000, w = sqrt(kSI / mass), c = 2 * zeta * mass * w / 1000;  // N per mm/s
    for (int i = 0; i < 100; i++) {
      const int64_t tEnd = tNow + 20;
      const double b0 = beltPos(rotor);
      while (running && nextEvt <= tEnd) {
        if (left) {
          --left;
          nextEvt += 0x4000;
        } else {
          step();
          left = chunks;
          nextEvt += first;
        }
      }
      tNow = tEnd;
      const double b = beltPos(rotor), bv = (b - b0) / dt;
      const double spring = k * (b - x) + c * (bv - v) + pushN;
      double a;
      if (fabs(v) < 1e-3 && fabs(spring) <= fric) {
        v = 0;
        a = 0;
      } else {
        const double f = spring - fric * (fabs(v) > 1e-3 ? (v > 0 ? 1 : -1) : (spring > 0 ? 1 : -1));
        a = f / mass * 1000;  // mm/s^2
      }
      const double xOld = x;
      v += a * dt;
      x += v * dt;
      // scale: decode the A/B state like the ISR
      const uint8_t s = stateOf(trueCount());
      if (s != encState) {
        int8_t d = axis::QDEC[(s << 2) | encState];
        encState = s;
        if (d == 2) {
          d = decDir * 2;
          ++decErrors;
        } else if (d) {
          decDir = d;
        }
        decoded += d;
      }
      if (refArmed) {
        for (int m = 0; m < 6; m++) {
          const double xm = refFirst + m * refPitch;
          if ((xOld < xm) != (x < xm)) {
            refCount = decoded;
            refSeen = true;
            refArmed = false;
          }
        }
      }
    }
  }
};

struct SimHal : axis::Hal {
  Plant& P;
  std::vector<std::string> out;
  bool verbose = false;
  explicit SimHal(Plant& p) : P(p) {}
  int32_t scaleCount() override { return P.decoded; }
  uint16_t scaleErrors() override { return P.decErrors; }
  int32_t stepCount() override { return P.steps; }
  void setStepRate(float sps) override { P.setRate(sps); }
  void enableMotor(bool on) override { P.enabled = on; }
  bool homeSwitch() override { return P.switchActive(); }
  void armRefMark() override {
    P.refSeen = false;
    P.refArmed = true;
  }
  bool refMark(int32_t& c) override {
    if (!P.refSeen) return false;
    c = P.refCount;
    return true;
  }
  void print(const char* line) override {
    out.push_back(line);
    if (verbose) printf("    << %s\n", line);
  }
};

axis::Config defaultConfig() {
  axis::Config c;
  c.letter = 'X';
  c.stepsPerMm = 160;
  c.motorDir = 1;
  c.mmPerCount = 0.005f;
  c.scaleDir = 1;
  c.minPos = 0;
  c.maxPos = 230;
  c.maxSpeed = 150;
  c.speed = 100;
  c.accel = 2000;
  c.maxFollow = 1.0f;
  c.deadband = 1;
  c.holdBand = 2;
  c.settleMs = 20;
  c.trimSpeed = 1;
  c.maxTrims = 10;
  c.homeDir = -1;
  c.homeFast = 20;
  c.homeSlow = 1;
  c.homeBackoff = 2;
  c.homeMaxTravel = 260;
  c.homePos = 0;
  c.useRefMark = true;
  c.refSearch = 60;
  c.refSpeed = 2;
  c.requireHoming = true;
  return c;
}

struct Sim {
  Plant P;
  SimHal H{P};
  axis::Axis A;
  uint64_t ms = 0;
  double truthZero = 0;  // true carriage x at machine 0, known after homing

  explicit Sim(const axis::Config& c, double x0 = 100) : A(H, c) {
    P.reset(x0);
    A.begin();
  }
  void run(int n) {
    for (int i = 0; i < n; i++) {
      A.tick();
      P.runMs();
      ++ms;
    }
  }
  // Like the sketch: a line waits while the axis is busy. Returns the reply
  // ("ok" or "error: ...") once one arrives; other lines go to `extra`.
  std::string send(const char* cmd, int timeoutMs = 60000, std::vector<std::string>* extra = nullptr) {
    char buf[64];
    strncpy(buf, cmd, sizeof(buf) - 1);
    buf[sizeof(buf) - 1] = 0;
    const size_t before = H.out.size();
    int t = 0;
    while (!A.command(buf)) {
      run(1);
      if (++t > timeoutMs) return "timeout";
    }
    for (;;) {
      for (size_t i = before; i < H.out.size(); i++) {
        const std::string& l = H.out[i];
        if (l.compare(0, 2, "ok") == 0 || l.compare(0, 5, "error") == 0) {
          if (extra) extra->assign(H.out.begin() + before, H.out.begin() + i);
          return l;
        }
      }
      run(1);
      if (++t > timeoutMs) return "timeout";
    }
  }
  // True position in machine coordinates (an ideal ruler, zero at the home point).
  double truth() const { return P.x - truthZero; }
};

static double homeSim(Sim& s, const char* label) {
  const uint64_t t0 = s.ms;
  const std::string r = s.send("G28");
  CHECK(r == "ok", "%s: G28 replied '%s'", label, r.c_str());
  // The machine zero is the reference mark the scale latched.
  s.truthZero = s.P.x - s.A.position();
  return (s.ms - t0) / 1000.0;
}

struct Stats {
  double maxAbs = 0, sumSq = 0;
  int n = 0, within5 = 0;
  void add(double e) {
    maxAbs = std::max(maxAbs, fabs(e));
    sumSq += e * e;
    if (fabs(e) <= 0.0051) ++within5;
    ++n;
  }
  double rms() const { return n ? sqrt(sumSq / n) : 0; }
};

// ---- tests -----------------------------------------------------------------

static void testDecoder() {
  printf("decoder table\n");
  std::mt19937 rng(1);
  int32_t truePos = 0, dec = 0;
  int8_t dir = 0;
  uint8_t prev = Plant::stateOf(0);
  for (int i = 0; i < 100000; i++) {
    truePos += (rng() % 3) - 1;  // random walk, one count at a time
    const uint8_t s = Plant::stateOf(truePos);
    int8_t d = axis::QDEC[(s << 2) | prev];
    prev = s;
    if (d) dir = d;
    dec += d;
  }
  CHECK(dec == truePos, "random walk decoded %d, true %d", dec, truePos);
  // A run with missed edges: jumps of 2 in a steady direction are recovered.
  truePos = 0;
  dec = 0;
  dir = 0;
  prev = Plant::stateOf(0);
  int errors = 0;
  for (int i = 0; i < 1000; i++) {
    truePos += (i % 7 == 3) ? 2 : 1;
    const uint8_t s = Plant::stateOf(truePos);
    int8_t d = axis::QDEC[(s << 2) | prev];
    prev = s;
    if (d == 2) {
      d = dir * 2;
      ++errors;
    } else if (d) {
      dir = d;
    }
    dec += d;
  }
  CHECK(dec == truePos && errors > 0, "missed edges: decoded %d, true %d, %d recovered", dec, truePos, errors);
}

static void testText() {
  printf("parser and number output\n");
  char l1[] = "g0 x10.5 f6000 ; comment";
  axis::cleanLine(l1);
  float g = -1, x = -1, f = -1;
  CHECK(axis::wordValue(l1, 'G', g) && g == 0, "G in '%s'", l1);
  CHECK(axis::wordValue(l1, 'X', x) && fabsf(x - 10.5f) < 1e-6f, "X in '%s'", l1);
  CHECK(axis::wordValue(l1, 'F', f) && f == 6000, "F in '%s'", l1);
  char l2[] = "G1 (a comment) X-3.25";
  axis::cleanLine(l2);
  CHECK(axis::wordValue(l2, 'X', x) && fabsf(x + 3.25f) < 1e-6f, "X in '%s'", l2);
  CHECK(std::string(axis::Line().f(12.34567f, 4).str()) == "12.3457", "f(12.34567)");
  CHECK(std::string(axis::Line().f(-0.00004f, 4).str()) == "0.0000", "f(-0.00004)");
  CHECK(std::string(axis::Line().f(-1.5f, 2).str()) == "-1.50", "f(-1.5)");
  CHECK(std::string(axis::Line().i(-12).i(0).str()) == "-120", "i()");
}

static void testProfile() {
  printf("trapezoid\n");
  axis::Trapezoid p;
  p.plan(0, 200, 150, 2000);
  CHECK(fabsf(p.T - 1.40833f) < 1e-4f, "T = %f", p.T);
  float pos, vel, lastP = 0;
  bool mono = true;
  for (float t = 0; t <= p.T + 0.01f; t += 0.001f) {
    p.sample(t, pos, vel);
    if (pos < lastP - 1e-4f) mono = false;
    lastP = pos;
  }
  CHECK(mono && fabsf(pos - 200) < 1e-4f && vel == 0, "end %f %f", pos, vel);
  p.plan(50, 49.99f, 150, 2000);  // short move backwards: triangular
  p.sample(p.T, pos, vel);
  CHECK(fabsf(pos - 49.99f) < 1e-5f && p.vp < 150, "short move end %f", pos);
}

static void testMoves(Sim& s, const char* label, Stats& vsTruth, Stats& vsScale, int n, double& meanTime) {
  std::mt19937 rng(7);
  std::uniform_real_distribution<double> u(0, 230);
  double tSum = 0;
  for (int i = 0; i < n; i++) {
    const double target = floor(u(rng) * 1000) / 1000;
    char cmd[48];
    snprintf(cmd, sizeof(cmd), "G0 X%.3f F9000", target);
    const uint64_t t0 = s.ms;
    std::string r = s.send(cmd);
    CHECK(r == "ok", "%s: %s -> %s", label, cmd, r.c_str());
    r = s.send("M400");
    CHECK(r == "ok", "%s: M400 after %s -> %s", label, cmd, r.c_str());
    tSum += (s.ms - t0) / 1000.0;
    s.run(50);  // let it ring out before measuring
    vsTruth.add(s.truth() - target);
    vsScale.add(s.A.scaleMm() - target);
  }
  meanTime = tSum / n;
}

int main() {
  testDecoder();
  testText();
  testProfile();

  printf("homing (5 starts)\n");
  std::vector<double> zeros;
  double homeTime = 0;
  for (int i = 0; i < 5; i++) {
    Sim s(defaultConfig(), 20 + 45 * i);
    homeTime = std::max(homeTime, homeSim(s, "home"));
    zeros.push_back(s.truthZero);
  }
  const double zSpread = *std::max_element(zeros.begin(), zeros.end()) - *std::min_element(zeros.begin(), zeros.end());
  printf("  machine zero repeatability %.1f um, slowest homing %.1f s\n", zSpread * 1000, homeTime);
  CHECK(zSpread <= 0.0051, "zero spread %.4f mm", zSpread);

  {
    printf("refusals\n");
    Sim s(defaultConfig());
    CHECK(s.send("G0 X10").rfind("error: not homed", 0) == 0, "move before homing");
    homeSim(s, "refusal");
    CHECK(s.send("G0 X300") == "error: target outside travel", "soft limit");
    CHECK(s.send("T1") == "error: unknown command", "unknown command");
  }

  Stats cTruth, cScale, oTruth, oScale;
  double cTime = 0, oTime = 0;
  {
    printf("200 random moves, closed loop\n");
    Sim s(defaultConfig());
    homeSim(s, "closed");
    testMoves(s, "closed", cTruth, cScale, 200, cTime);
    std::vector<std::string> diag;
    s.send("M122", 1000, &diag);
    for (auto& l : diag) printf("    %s\n", l.c_str());
  }
  {
    printf("200 random moves, open loop (M901 S0)\n");
    Sim s(defaultConfig());
    homeSim(s, "open");
    CHECK(s.send("M901 S0") == "ok", "M901 S0");
    testMoves(s, "open", oTruth, oScale, 200, oTime);
  }
  printf("  error vs an ideal ruler:  closed loop max %5.1f um rms %4.1f um | open loop max %5.1f um rms %4.1f um\n",
         cTruth.maxAbs * 1000, cTruth.rms() * 1000, oTruth.maxAbs * 1000, oTruth.rms() * 1000);
  printf("  error vs the scale:       closed loop max %5.1f um rms %4.1f um, %d of %d within +-5 um\n",
         cScale.maxAbs * 1000, cScale.rms() * 1000, cScale.within5, cScale.n);
  printf("  mean time per move incl. settling: closed %.3f s, open %.3f s\n", cTime, oTime);
  CHECK(cScale.maxAbs <= 0.0101, "closed loop vs scale %.4f mm", cScale.maxAbs);  // HOLD_BAND
  CHECK(cTruth.maxAbs <= 0.0151, "closed loop vs truth %.4f mm", cTruth.maxAbs);
  CHECK(oTruth.maxAbs > 2 * cTruth.maxAbs, "open loop should be clearly worse");

  {
    printf("long move timing\n");
    Sim s(defaultConfig());
    homeSim(s, "timing");
    s.send("G0 X0 F9000");
    s.send("M400");
    s.run(100);
    const uint64_t t0 = s.ms;
    s.send("G0 X200 F9000");
    CHECK(s.send("M400") == "ok", "M400");
    printf("  0 -> 200 mm at 150 mm/s: done after %.3f s (profile 1.408 s), error %.1f um\n",
           (s.ms - t0) / 1000.0, (s.truth() - 200) * 1000);
  }
  {
    printf("belt jumps 0.4 mm during a move\n");
    Sim s(defaultConfig());
    homeSim(s, "skip");
    s.send("G0 X50 F9000");
    s.send("M400");
    s.send("G0 X150 F9000");
    s.run(300);
    s.P.beltOffset += 0.4;
    const std::string r = s.send("M400");
    s.run(50);
    CHECK(r == "ok", "M400 -> %s", r.c_str());
    printf("  final error %.1f um (open loop would be off by 400 um)\n", (s.truth() - 150) * 1000);
    CHECK(fabs(s.truth() - 150) < 0.012, "after belt jump %.4f", s.truth() - 150);
  }
  {
    printf("motor stalls during a move\n");
    Sim s(defaultConfig());
    homeSim(s, "stall");
    s.send("G0 X20 F9000");
    s.send("M400");
    s.send("G0 X180 F9000");
    s.run(200);
    s.P.stalled = true;
    const std::string r = s.send("M400");
    CHECK(r.rfind("error: following error", 0) == 0, "M400 -> %s", r.c_str());
    printf("  M400 -> %s\n", r.c_str());
    s.P.stalled = false;
    CHECK(s.send("G0 X30").rfind("error", 0) == 0, "moves refused while faulted");
    CHECK(s.send("M999") == "ok", "M999");
    s.send("G0 X30");
    CHECK(s.send("M400") == "ok", "move after M999");
    s.run(50);
    printf("  after M999, no re-homing: error %.1f um\n", (s.truth() - 30) * 1000);
    CHECK(fabs(s.truth() - 30) < 0.012, "after stall %.4f", s.truth() - 30);
  }
  {
    printf("abort with '!'\n");
    Sim s(defaultConfig());
    homeSim(s, "abort");
    s.send("G0 X200 F9000");
    s.run(150);
    s.A.abort();
    CHECK(s.send("M400").rfind("error: aborted", 0) == 0, "M400 after abort");
    CHECK(s.send("M999") == "ok", "M999");
    s.send("G0 X10");
    CHECK(s.send("M400") == "ok", "move after abort");
    s.run(50);
    CHECK(fabs(s.truth() - 10) < 0.012, "after abort %.4f", s.truth() - 10);
  }
  {
    printf("carriage pushed with 3 N for 50 ms while holding\n");
    Sim s(defaultConfig());
    homeSim(s, "push");
    s.send("G0 X100");
    s.send("M400");
    s.run(100);
    s.P.pushN = 3;
    s.run(50);
    const double pushed = s.truth() - 100;
    s.P.pushN = 0;
    s.run(500);
    printf("  pushed %.1f um, error 0.5 s after release %.1f um\n", pushed * 1000, (s.truth() - 100) * 1000);
    CHECK(fabs(pushed) > 0.015, "push too small %.4f", pushed);
    CHECK(fabs(s.truth() - 100) < 0.012, "after push %.4f", s.truth() - 100);
  }
  {
    printf("scale direction set wrong\n");
    axis::Config c = defaultConfig();
    c.scaleDir = -1;
    Sim s(c);
    CHECK(s.send("G92 X100") == "ok", "G92");
    const double x0 = s.P.x;
    s.send("G0 X110");
    const std::string r = s.send("M400");
    printf("  M400 -> %s, carriage moved %.2f mm\n", r.c_str(), s.P.x - x0);
    CHECK(r.rfind("error", 0) == 0, "expected a fault");
    CHECK(fabs(s.P.x - x0) < 3, "runaway %.2f mm", s.P.x - x0);
  }
  {
    printf("M900 open-loop check\n");
    Sim s(defaultConfig());
    homeSim(s, "m900");
    s.send("G0 X50");
    s.send("M400");
    std::vector<std::string> lines;
    const std::string r = s.send("M900 X20", 10000, &lines);
    CHECK(r == "ok", "M900 -> %s", r.c_str());
    for (auto& l : lines) printf("    %s\n", l.c_str());
    float ratio = 0;
    for (auto& l : lines)
      if (l.rfind("ratio", 0) == 0) ratio = (float)atof(l.c_str() + 17);
    CHECK(fabsf(ratio - 1) < 0.01f, "ratio %f", ratio);
  }

  printf(failures ? "\n%d FAILED\n" : "\nall tests passed\n", failures);
  return failures ? 1 : 0;
}
