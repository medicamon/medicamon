// axis_core.h: closed-loop axis logic that does not depend on the board.
//
// The sketch supplies a Hal (scale count, step count, step rate, home switch,
// serial output). tick() runs the control loop once per millisecond and
// command() handles one line of G-code. test/sim_test.cpp runs this same code
// against a simulated belt axis.
//
// Control. The scale sits on the far side of a springy belt, so the carriage
// rings at the belt's resonance (tens of Hz) after every move. Feeding the
// scale back continuously through that resonance can make the loop unstable,
// so the scale is used in two ways that cannot:
//  - During a move the motor follows a trapezoidal profile by its own step
//    count (exact, no resonance in that loop). The scale is only checked
//    against the plan: a following error over MAX_FOLLOW stops the axis.
//  - At the end, the axis trims: it waits until the scale is steady, then
//    creeps toward the target at TRIM_SPEED, reading the scale every tick.
//    It stops inside the band, on overshoot, or (near the target) as soon as
//    the carriage moves. Friction holds the carriage until the belt has
//    stretched, then it jumps; stopping at once keeps the jump short. Repeat
//    until steady inside DEADBAND counts, or HOLD_BAND after FINE_TRIES.
// At rest it holds the same way whenever the error exceeds HOLD_BAND.
#pragma once

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

namespace axis {

// Quadrature decoding. State s = A | (B << 1); index = current * 4 + previous.
// Counting up, s runs 0, 1, 3, 2, 0. +1 or -1 is one count, 0 is no change.
// 2 means both lines changed at once: an edge was missed, so the count moves
// 2 in the last known direction.
static const int8_t QDEC[16] = {
   0, -1,  1,  2,  // current 0, previous 0..3
   1,  0,  2, -1,  // current 1
  -1,  2,  0,  1,  // current 2
   2,  1, -1,  0,  // current 3
};

struct Config {
  char letter;           // G-code axis letter
  float stepsPerMm;
  int8_t motorDir;       // +1 or -1
  float mmPerCount;
  int8_t scaleDir;       // +1 or -1
  float minPos, maxPos;  // soft limits (mm), applied once homed
  float maxSpeed;        // mm/s
  float speed;           // default speed, mm/s
  float accel;           // mm/s^2
  float maxFollow;       // mm
  int16_t deadband;      // counts
  int16_t holdBand;      // counts
  uint16_t settleMs;     // steady time before a trim
  float trimSpeed;       // creep speed, mm/s
  uint8_t maxTrims;
  int8_t homeDir;        // -1 or +1: direction of the switch
  float homeFast, homeSlow, homeBackoff, homeMaxTravel, homePos;
  bool useRefMark;
  float refSearch, refSpeed;
  bool requireHoming;
};

// What the axis needs from the board.
class Hal {
 public:
  virtual int32_t scaleCount() = 0;
  virtual uint16_t scaleErrors() = 0;          // missed-edge recoveries
  virtual int32_t stepCount() = 0;
  virtual void setStepRate(float stepsPerSecond) = 0;  // signed, 0 stops at once
  virtual void enableMotor(bool on) = 0;
  virtual bool homeSwitch() = 0;
  virtual void armRefMark() = 0;               // latch the count at the next reference pulse
  virtual bool refMark(int32_t& count) = 0;    // true once a pulse was latched
  virtual void print(const char* line) = 0;    // one line, newline added
};

// Builds one output line. printf has no float support on AVR.
class Line {
 public:
  Line() : n_(0) { buf_[0] = 0; }
  Line& s(const char* t) {
    while (*t) c(*t++);
    return *this;
  }
  Line& c(char ch) {
    if (n_ < sizeof(buf_) - 1) {
      buf_[n_++] = ch;
      buf_[n_] = 0;
    }
    return *this;
  }
  Line& i(int32_t v) {
    char tmp[11];
    uint8_t k = 0;
    uint32_t u = v < 0 ? 0u - (uint32_t)v : (uint32_t)v;
    do {
      tmp[k++] = char('0' + u % 10);
      u /= 10;
    } while (u);
    if (v < 0) c('-');
    while (k) c(tmp[--k]);
    return *this;
  }
  Line& f(float v, uint8_t dec) {
    uint32_t scale = 1;
    for (uint8_t k = 0; k < dec; k++) scale *= 10;
    const bool neg = v < 0;
    if (neg) v = -v;
    const uint32_t n = (uint32_t)(v * (float)scale + 0.5f);
    if (neg && n) c('-');
    i((int32_t)(n / scale));
    if (dec) {
      c('.');
      const uint32_t frac = n % scale;
      for (uint32_t d = scale / 10; d; d /= 10) c(char('0' + (frac / d) % 10));
    }
    return *this;
  }
  const char* str() const { return buf_; }

 private:
  char buf_[96];
  uint8_t n_;
};

// Upper-cases a line and removes comments: "; ..." and "( ... )".
inline void cleanLine(char* line) {
  char* w = line;
  bool paren = false;
  for (char* r = line; *r; ++r) {
    char ch = *r;
    if (paren) {
      if (ch == ')') paren = false;
      continue;
    }
    if (ch == '(') {
      paren = true;
      continue;
    }
    if (ch == ';') break;
    if (ch >= 'a' && ch <= 'z') ch = char(ch - 32);
    *w++ = ch;
  }
  *w = 0;
}

inline bool blankLine(const char* s) {
  for (; *s; ++s)
    if (*s != ' ' && *s != '\t') return false;
  return true;
}

// Value of a word such as X in "G0 X12.5"; false if the line has none.
inline bool wordValue(const char* line, char letter, float& value) {
  for (const char* p = line; *p; ++p) {
    if (*p != letter) continue;
    char* end;
    const double v = strtod(p + 1, &end);
    if (end != p + 1) {
      value = (float)v;
      return true;
    }
  }
  return false;
}

inline float clampAbs(float v, float limit) {
  return v > limit ? limit : (v < -limit ? -limit : v);
}

// Rest-to-rest trapezoidal (or triangular) speed profile.
struct Trapezoid {
  float p0 = 0, dist = 0, dir = 1, a = 1, vp = 0, t1 = 0, tc = 0, T = 0;

  void plan(float from, float to, float vmax, float acc) {
    p0 = from;
    const float d = to - from;
    dir = d < 0 ? -1.0f : 1.0f;
    dist = fabsf(d);
    a = acc;
    if (dist * a < vmax * vmax) {  // never reaches vmax
      vp = sqrtf(dist * a);
      t1 = vp / a;
      tc = 0;
    } else {
      vp = vmax;
      t1 = vmax / a;
      tc = (dist - vmax * vmax / a) / vmax;
    }
    T = 2 * t1 + tc;
  }

  // Planned position and speed t seconds after the start.
  void sample(float t, float& p, float& v) const {
    float s, sp;
    if (t <= 0) {
      s = 0;
      sp = 0;
    } else if (t < t1) {
      s = 0.5f * a * t * t;
      sp = a * t;
    } else if (t < t1 + tc) {
      s = 0.5f * a * t1 * t1 + vp * (t - t1);
      sp = vp;
    } else if (t < T) {
      const float td = T - t;
      s = dist - 0.5f * a * td * td;
      sp = a * td;
    } else {
      s = dist;
      sp = 0;
    }
    p = p0 + dir * s;
    v = dir * sp;
  }
};

class Axis {
 public:
  enum Mode : uint8_t { IDLE, MOVING, TRIMMING, JOGGING, STOPPING, FAULT };

  Axis(Hal& hal, const Config& cfg)
      : hal_(hal), cfg_(cfg), speed_(cfg.speed), accel_(cfg.accel), mmPerStep_(1 / cfg.stepsPerMm) {}

  void begin() {
    hal_.enableMotor(false);
    target_ = position();
    hal_.print(Line().s("scale_axis ").c(cfg_.letter).s(" ready").str());
  }

  // Control loop, once per millisecond.
  void tick() {
    ++now_;
    const float p = position();
    switch (mode_) {
      case IDLE: hold(p); break;
      case MOVING: moving(p); break;
      case TRIMMING: trimming(p); break;
      case JOGGING: jogging(p); break;
      case STOPPING: stopping(p); break;
      case FAULT:
        output(0);
        target_ = p;
        break;
    }
    if (home_ != H_NONE) homing(p);
    if (test_ != T_NONE) testing();
  }

  // Handles one line. Returns false while the axis is busy: call again later
  // with the same line. Every command waits, queries too: a long reply can
  // block the serial port for milliseconds, which must not happen mid-move.
  bool command(char* line) {
    if (busy()) return false;
    cleanLine(line);
    if (blankLine(line)) {
      hal_.print("ok");
      return true;
    }
    float num;
    char kind = 0;
    int code = -1;
    if (wordValue(line, 'G', num)) {
      kind = 'G';
      code = (int)num;
    } else if (wordValue(line, 'M', num)) {
      kind = 'M';
      code = (int)num;
    }
    if (kind == 'M' && (code == 114 || code == 119 || code == 122)) {
      report(code);
      return true;
    }
    if (kind == 'G') return gcode(code, line);
    if (kind == 'M') return mcode(code, line);
    hal_.print("error: unknown command");
    return true;
  }

  // Realtime stop ('!'). The scale keeps the position, so M999 is enough to go on.
  void abort() {
    if (busy()) fail("aborted");
  }

  bool busy() const {
    return (mode_ != IDLE && mode_ != FAULT) || home_ != H_NONE || test_ != T_NONE;
  }
  Mode mode() const { return mode_; }
  bool homed() const { return homed_; }
  float target() const { return target_; }
  const char* fault() const { return fault_; }

  // Position in mm: from the scale, or from the step count in open loop.
  float position() { return useScale() ? scaleMm() : motorMm(); }
  float scaleMm() { return cfg_.scaleDir * hal_.scaleCount() * cfg_.mmPerCount + scaleOff_; }
  float motorMm() { return cfg_.motorDir * hal_.stepCount() * mmPerStep_ + stepOff_; }

  uint32_t overruns = 0;  // late control ticks, counted by the sketch

 private:
  enum Home : uint8_t {
    H_NONE, H_START, H_CLEAR, H_FAST, H_FAST_STOP, H_BACK, H_SLOW, H_SLOW_STOP, H_REF, H_REF_STOP
  };
  enum Test : uint8_t { T_NONE, T_MOVE, T_WAIT };
  static constexpr float DT = 0.001f;
  static constexpr float EPS = 1e-6f;
  static constexpr float KP_STEPS = 50;    // 1/s, motor step count to plan
  static constexpr float CORR_LIMIT = 20;  // mm/s
  static constexpr uint8_t FINE_TRIES = 4; // creeps that aim for DEADBAND
  static constexpr int16_t NEAR_COUNTS = 4;

  bool useScale() const { return closedLoop_ && test_ == T_NONE; }

  void output(float v) {
    v = clampAbs(v, cfg_.maxSpeed + CORR_LIMIT);
    vOut_ = v;
    hal_.setStepRate(v * cfg_.stepsPerMm * cfg_.motorDir);
  }

  // ---- modes ----

  void hold(float p) {
    output(0);
    if (!enabled_) {
      target_ = p;
      return;
    }
    const float e = target_ - p;
    if (fabsf(e) > cfg_.maxFollow) {
      fail("position lost while holding");
      return;
    }
    if (fabsf(e) > cfg_.holdBand * cfg_.mmPerCount + EPS) {
      trims_ = 0;
      startTrim();
    }
  }

  void moving(float p) {
    const float t = (now_ - phaseStart_) * DT;
    float pc, vc;
    prof_.sample(t, pc, vc);
    const float e = pc - p;
    if (fabsf(e) > maxErr_) maxErr_ = fabsf(e);
    if (fabsf(e) > cfg_.maxFollow) {
      fail("following error");
      return;
    }
    // the motor follows the plan by its step count
    output(vc + clampAbs(KP_STEPS * (pc - motorMm()), CORR_LIMIT));
    if (t >= prof_.T) startTrim();
  }

  void trimming(float p) {
    const float e = target_ - p;
    if (fabsf(e) > cfg_.maxFollow) {
      fail("following error");
      return;
    }
    if (now_ - phaseStart_ > 2000) {  // never settled: give up, counted in M122
      ++trimFailures_;
      creep_ = 0;
      output(0);
      mode_ = IDLE;
      return;
    }
    // Aim for DEADBAND; after FINE_TRIES creeps accept HOLD_BAND.
    const int16_t band = trims_ < FINE_TRIES ? cfg_.deadband : cfg_.holdBand;
    const bool inBand = fabsf(e) <= band * cfg_.mmPerCount + EPS;
    if (creep_) {  // creeping toward the target, reading the scale every tick
      // Near the target, stop as soon as the carriage moves: the belt then
      // releases its stretch in one stick-slip jump instead of being driven on.
      const bool moved = creepNear_ && fabsf(p - creepFrom_) >= cfg_.mmPerCount - EPS;
      if (inBand || moved || (e > 0) != (creep_ > 0)) {
        creep_ = 0;
        output(0);
        steadyAt_ = p;
        steadySince_ = now_;
      }
      return;
    }
    output(0);
    if (fabsf(p - steadyAt_) > cfg_.mmPerCount + EPS) {  // still moving
      steadyAt_ = p;
      steadySince_ = now_;
    }
    if (now_ - steadySince_ < cfg_.settleMs) return;
    if (inBand) {
      mode_ = IDLE;
      return;
    }
    if (trims_ >= cfg_.maxTrims) {
      ++trimFailures_;
      mode_ = IDLE;
      return;
    }
    ++trims_;
    creep_ = e > 0 ? 1 : -1;
    creepFrom_ = p;
    creepNear_ = fabsf(e) <= NEAR_COUNTS * cfg_.mmPerCount + EPS;
    output(creep_ * cfg_.trimSpeed);
  }

  void jogging(float p) {
    output(vOut_ + clampAbs(jogV_ - vOut_, accel_ * DT));
    if (fabsf(p - jogFrom_) > jogLimit_)
      fail(home_ == H_REF ? "reference mark not found" : "home switch not found");
  }

  void stopping(float p) {
    const float dv = accel_ * DT;
    if (fabsf(vOut_) <= dv) {
      output(0);
      target_ = p;
      mode_ = afterStop_;
    } else {
      output(vOut_ - (vOut_ > 0 ? dv : -dv));
    }
  }

  void startMove(float to, float v) {
    if (useScale()) syncMotorToScale();  // plan and motor start from the scale reading
    prof_.plan(position(), to, v, accel_);
    target_ = to;
    maxErr_ = 0;
    trims_ = 0;
    phaseStart_ = now_;
    mode_ = MOVING;
  }

  void startTrim() {
    mode_ = TRIMMING;
    phaseStart_ = now_;
    creep_ = 0;
    steadyAt_ = position();
    steadySince_ = now_;
  }

  void startJog(float v, float limit) {
    jogV_ = v;
    jogFrom_ = position();
    jogLimit_ = limit;
    mode_ = JOGGING;
  }

  void stop(Mode after) {
    afterStop_ = after;
    mode_ = STOPPING;
  }

  void fail(const char* msg) {
    fault_ = msg;
    if (home_ != H_NONE || test_ != T_NONE) {  // G28 or M900 is waiting for its reply
      home_ = H_NONE;
      test_ = T_NONE;
      replyError();
    }
    stop(FAULT);
  }

  void replyError() { hal_.print(Line().s("error: ").s(fault_).s(" (M999 clears)").str()); }

  void enable() {
    if (enabled_) return;
    enabled_ = true;
    hal_.enableMotor(true);
    target_ = position();
  }

  void disable() {
    enabled_ = false;
    output(0);
    hal_.enableMotor(false);
  }

  void syncMotorToScale() {
    stepOff_ = scaleMm() - cfg_.motorDir * hal_.stepCount() * mmPerStep_;
  }

  void setPosition(float x) {
    scaleOff_ = x - cfg_.scaleDir * hal_.scaleCount() * cfg_.mmPerCount;
    stepOff_ = x - cfg_.motorDir * hal_.stepCount() * mmPerStep_;
    target_ = x;
  }

  // ---- homing: fast to the switch, back off, slow to the switch, then the
  // first reference mark on the way back (if enabled) ----

  void homing(float p) {
    const bool sw = hal_.homeSwitch();
    const float d = cfg_.homeDir;
    switch (home_) {
      case H_START:
        if (sw) {
          startMove(p - d * cfg_.homeBackoff, cfg_.homeFast);
          home_ = H_CLEAR;
        } else {
          startJog(d * cfg_.homeFast, cfg_.homeMaxTravel);
          home_ = H_FAST;
        }
        break;
      case H_CLEAR:
        if (mode_ != IDLE) break;
        if (sw) {
          fail("home switch stays on");
          break;
        }
        startJog(d * cfg_.homeFast, cfg_.homeMaxTravel);
        home_ = H_FAST;
        break;
      case H_FAST:
        if (mode_ == JOGGING && sw) {
          stop(IDLE);
          home_ = H_FAST_STOP;
        }
        break;
      case H_FAST_STOP:
        if (mode_ != IDLE) break;
        startMove(p - d * cfg_.homeBackoff, cfg_.homeFast);
        home_ = H_BACK;
        break;
      case H_BACK:
        if (mode_ != IDLE) break;
        if (sw) {
          fail("home switch stays on");
          break;
        }
        startJog(d * cfg_.homeSlow, 2 * cfg_.homeBackoff + 1);
        home_ = H_SLOW;
        break;
      case H_SLOW:
        if (mode_ == JOGGING && sw) {
          homeCount_ = hal_.scaleCount();
          homeSteps_ = hal_.stepCount();
          stop(IDLE);
          home_ = H_SLOW_STOP;
        }
        break;
      case H_SLOW_STOP:
        if (mode_ != IDLE) break;
        if (cfg_.useRefMark && closedLoop_) {
          hal_.armRefMark();
          startJog(-d * cfg_.refSpeed, cfg_.refSearch);
          home_ = H_REF;
        } else {
          finishHome();
        }
        break;
      case H_REF: {
        int32_t c;
        if (mode_ == JOGGING && hal_.refMark(c)) {
          homeCount_ = c;
          homeSteps_ = hal_.stepCount();
          stop(IDLE);
          home_ = H_REF_STOP;
        }
        break;
      }
      case H_REF_STOP:
        if (mode_ == IDLE) finishHome();
        break;
      default:
        break;
    }
  }

  void finishHome() {
    // The latched point (switch or reference mark) becomes homePos.
    scaleOff_ = cfg_.homePos - cfg_.scaleDir * homeCount_ * cfg_.mmPerCount;
    stepOff_ = cfg_.homePos - cfg_.motorDir * homeSteps_ * mmPerStep_;
    if (closedLoop_) syncMotorToScale();
    target_ = position();
    homed_ = true;
    home_ = H_NONE;
    hal_.print("ok");
  }

  // ---- M900: open-loop test move, compares steps with the scale ----

  void testing() {
    if (test_ == T_MOVE) {
      if (mode_ == IDLE) {
        test_ = T_WAIT;
        phaseStart_ = now_;
      }
      return;
    }
    if (now_ - phaseStart_ < 300) return;  // let the carriage settle
    const int32_t ds = hal_.stepCount() - testSteps_;
    const int32_t dc = hal_.scaleCount() - testCount_;
    const float motor = cfg_.motorDir * ds * mmPerStep_;
    const float scale = cfg_.scaleDir * dc * cfg_.mmPerCount;
    test_ = T_NONE;
    if (closedLoop_) syncMotorToScale();
    target_ = position();
    hal_.print(Line().s("motor ").f(motor, 4).s(" mm (").i(ds).s(" steps), scale ")
                   .f(scale, 4).s(" mm (").i(dc).s(" counts)").str());
    if (fabsf(motor) > 0.01f) {
      const float ratio = scale / motor;
      hal_.print(Line().s("ratio scale/motor ").f(ratio, 5).str());
      if (ratio < 0)
        hal_.print("echo: scale and motor disagree in sign: flip SCALE_DIR or MOTOR_DIR");
      else if (fabsf(ratio - 1) > 0.02f)
        hal_.print("echo: ratio is off by more than 2 %: check STEPS_PER_MM and MM_PER_COUNT");
    }
    hal_.print("ok");
  }

  // ---- G-code ----

  bool gcode(int code, const char* line) {
    switch (code) {
      case 0:
      case 1: return move(line);
      case 20: hal_.print("error: inch units are not supported"); return true;
      case 28: {
        enable();
        fault_ = nullptr;
        if (mode_ == FAULT) mode_ = IDLE;
        target_ = position();
        homed_ = false;
        home_ = H_START;  // "ok" is sent when homing ends
        return true;
      }
      case 90: relative_ = false; break;
      case 91: relative_ = true; break;
      case 92: {
        float x;
        if (wordValue(line, cfg_.letter, x)) {
          setPosition(x);
          homed_ = true;
        }
        break;
      }
      default: break;  // G4, G21 and others: accepted, nothing to do
    }
    hal_.print("ok");
    return true;
  }

  bool move(const char* line) {
    float f;
    if (wordValue(line, 'F', f) && f > 0) speed_ = f / 60 < cfg_.maxSpeed ? f / 60 : cfg_.maxSpeed;
    float x;
    if (!wordValue(line, cfg_.letter, x)) {
      hal_.print("ok");
      return true;
    }
    if (mode_ == FAULT) {
      replyError();
      return true;
    }
    if (relative_) x += target_;
    if (cfg_.requireHoming && !homed_) {
      hal_.print("error: not homed: send G28");
      return true;
    }
    if (homed_ && (x < cfg_.minPos - EPS || x > cfg_.maxPos + EPS)) {
      hal_.print("error: target outside travel");
      return true;
    }
    enable();
    startMove(x, speed_);
    hal_.print("ok");  // accepted; M400 waits for the end
    return true;
  }

  bool mcode(int code, const char* line) {
    float v;
    switch (code) {
      case 17: enable(); break;
      case 18: disable(); break;
      case 92:  // steps per mm
        if (wordValue(line, cfg_.letter, v) && v > 0) {
          cfg_.stepsPerMm = v;
          mmPerStep_ = 1 / v;
          syncMotorToScale();
        }
        break;
      case 203:  // max speed, mm/s
        if (wordValue(line, cfg_.letter, v) && v > 0) cfg_.maxSpeed = v;
        if (speed_ > cfg_.maxSpeed) speed_ = cfg_.maxSpeed;
        break;
      case 204:  // acceleration, mm/s^2
        if (wordValue(line, 'S', v) && v > 0) accel_ = v;
        break;
      case 400:  // wait for the end of motion (command() held it while busy)
        if (mode_ == FAULT) {
          replyError();
          return true;
        }
        break;
      case 900: {  // open-loop test move: M900 X<distance>
        if (mode_ == FAULT) {
          replyError();
          return true;
        }
        float dist = 10;
        wordValue(line, cfg_.letter, dist);
        enable();
        testSteps_ = hal_.stepCount();
        testCount_ = hal_.scaleCount();
        test_ = T_MOVE;          // position() now follows the steps
        target_ = position();
        startMove(target_ + dist, speed_ < 20 ? speed_ : 20);
        return true;             // the report and "ok" come when it ends
      }
      case 901:  // M901 S1 closed loop, S0 open loop (steps only)
        if (wordValue(line, 'S', v)) {
          closedLoop_ = v != 0;
          if (closedLoop_) syncMotorToScale();
          target_ = position();
        }
        break;
      case 999:  // clear a fault
        fault_ = nullptr;
        if (mode_ == FAULT) mode_ = IDLE;
        target_ = position();
        break;
      default: break;  // other M-codes: accepted, nothing to do
    }
    hal_.print("ok");
    return true;
  }

  void report(int code) {
    if (code == 114) {
      const float p = position();
      hal_.print(Line().c(cfg_.letter).c(':').f(p, 4).s(" T:").f(target_, 4).s(" E:")
                     .f(target_ - p, 4).s(" M:").f(motorMm(), 4).s(" C:").i(hal_.scaleCount()).str());
    } else if (code == 119) {
      hal_.print(hal_.homeSwitch() ? "home: TRIGGERED" : "home: open");
    } else {
      static const char* const names[] = {"idle", "moving", "trimming", "jogging", "stopping", "fault"};
      hal_.print(Line().s("mode:").s(names[mode_]).s(" homed:").i(homed_).s(" enabled:").i(enabled_)
                     .s(closedLoop_ ? " loop:closed" : " loop:open").str());
      hal_.print(Line().s("scale missed edges:").i(hal_.scaleErrors()).s(" last move max error:")
                     .f(maxErr_, 4).s(" trim failures:").i(trimFailures_).s(" overruns:").i(overruns).str());
      hal_.print(Line().s("fault:").s(fault_ ? fault_ : "none").str());
    }
    hal_.print("ok");
  }

  Hal& hal_;
  Config cfg_;
  Mode mode_ = IDLE;
  Mode afterStop_ = IDLE;
  Home home_ = H_NONE;
  Test test_ = T_NONE;
  bool enabled_ = false, homed_ = false, closedLoop_ = true, relative_ = false;
  float speed_, accel_, mmPerStep_;
  float target_ = 0, vOut_ = 0, maxErr_ = 0, steadyAt_ = 0;
  float scaleOff_ = 0, stepOff_ = 0;
  float jogV_ = 0, jogFrom_ = 0, jogLimit_ = 0;
  Trapezoid prof_;
  uint32_t now_ = 0, phaseStart_ = 0, steadySince_ = 0;
  int32_t homeCount_ = 0, homeSteps_ = 0, testCount_ = 0, testSteps_ = 0;
  int8_t creep_ = 0;
  bool creepNear_ = false;
  float creepFrom_ = 0;
  uint8_t trims_ = 0;
  uint16_t trimFailures_ = 0;
  const char* fault_ = nullptr;
};

}  // namespace axis
