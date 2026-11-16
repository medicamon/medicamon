// scale_axis.ino: one closed-loop axis for the pnp-200.
//
// A glass scale (5 V TTL, A/B/Z) measures the carriage and a TMC2209 drives
// the stepper. The board answers a small G-code set over USB serial; see
// README.md for wiring, commands and setup. Settings are in config.h.
//
// Board: ATmega328P at 16 MHz, 5 V (Arduino Uno, Nano, Pro Mini 5 V).
//
//   D2  scale A  (INT0)           D5  STEP -> TMC2209 STEP
//   D3  scale B  (INT1)           D7  DIR  -> TMC2209 DIR
//   D4  scale Z  (pin change)     D8  EN   -> TMC2209 EN (low = motor on)
//   D6  home switch to GND        D13 LED: on when homed and at rest
//                                 D12 control-loop probe (TICK_PROBE in config.h)
//
// The pin numbers are fixed: the interrupt code reads PIND directly.

#include <Arduino.h>
#include <util/atomic.h>

#include "config.h"
#include "axis_core.h"

#if !defined(__AVR_ATmega328P__) || F_CPU != 16000000L
#error "scale_axis needs an ATmega328P at 16 MHz (Uno, Nano, Pro Mini 5 V)"
#endif

// Timer1 runs free at 16 MHz / 8 = 2 MHz (0.5 us per tick) and times the steps.
const float TIMER_HZ = 2000000.0f;
const uint16_t MIN_PERIOD = 50;  // 25 us: at most 40,000 steps/s
const float MIN_RATE = 1.0f;     // below 1 step/s counts as stopped

static_assert(MAX_SPEED_MM_S * STEPS_PER_MM <= 40000.0f, "MAX_SPEED_MM_S needs more than 40,000 steps/s");
static_assert(MAX_SPEED_MM_S / MM_PER_COUNT <= 40000.0f, "MAX_SPEED_MM_S needs more than 40,000 scale counts/s");

// ---- scale: quadrature on D2 (A) and D3 (B), reference mark on D4 ----
// The interrupts keep 16-bit counts so they stay short; AvrHal extends them
// to 32 bits every millisecond. GPIOR0 holds the previous A/B state.

volatile uint16_t encRaw = 0;
volatile int8_t encDir = 0;
volatile uint16_t encErrors = 0;
volatile uint16_t refRaw = 0;
volatile bool refArmed = false;
volatile bool refSeen = false;

ISR(INT0_vect) {
  const uint8_t now = PIND & 0x0C;      // A = PD2, B = PD3
  int8_t d = axis::QDEC[now | GPIOR0];  // index = current * 4 + previous
  GPIOR0 = now >> 2;
  if (d == 2) {  // both lines changed: an edge was missed
    d = encDir * 2;
    ++encErrors;
  } else if (d) {
    encDir = d;
  }
  encRaw += d;
}
ISR_ALIAS(INT1_vect, INT0_vect);

ISR(PCINT2_vect) {
  const bool high = PIND & _BV(PD4);
  if (refArmed && high == (REF_ACTIVE_HIGH != 0)) {
    refRaw = encRaw;
    refSeen = true;
    refArmed = false;
  }
}

// ---- steps: Timer1 compare A, STEP on D5, DIR on D7 ----
// After each step the next compare is stepFirst ticks later, followed by
// stepChunks waits of 0x4000 ticks for rates too slow for one 16-bit compare.

volatile uint16_t stepRaw = 0;
volatile int8_t stepSign = 1;
volatile uint16_t stepFirst = 0;
volatile uint8_t stepChunks = 0;
volatile uint8_t stepLeft = 0;

ISR(TIMER1_COMPA_vect) {
  if (stepLeft) {
    --stepLeft;
    OCR1A += 0x4000;
    return;
  }
  PORTD |= _BV(PD5);  // STEP high
  stepRaw += stepSign;
  const uint16_t first = stepFirst;
  stepLeft = stepChunks;
  PORTD &= ~_BV(PD5);  // STEP low, about 1 us later
  OCR1A += first;
  if ((int16_t)(OCR1A - TCNT1) < 8) OCR1A = TCNT1 + 8;  // running late: step soon, not after a wrap
}

class AvrHal : public axis::Hal {
 public:
  int32_t scaleCount() override {
    uint16_t raw;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { raw = encRaw; }
    encFull_ += (int16_t)(raw - encLast_);
    encLast_ = raw;
    return encFull_;
  }
  uint16_t scaleErrors() override {
    uint16_t e;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { e = encErrors; }
    return e;
  }
  int32_t stepCount() override {
    uint16_t raw;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) { raw = stepRaw; }
    stepFull_ += (int16_t)(raw - stepLast_);
    stepLast_ = raw;
    return stepFull_;
  }

  void setStepRate(float sps) override {
    if (sps == lastRate_) return;
    lastRate_ = sps;
    const float a = fabsf(sps);
    if (a < MIN_RATE) {
      TIMSK1 &= ~_BV(OCIE1A);  // stop now, drop the pending step
      return;
    }
    const float t = TIMER_HZ / a;
    const uint32_t period = t < MIN_PERIOD ? MIN_PERIOD : (uint32_t)t;
    uint16_t first;
    uint8_t chunks;
    if (period <= 0x7000) {
      first = period;
      chunks = 0;
    } else {  // first ends up between 0x2000 and 0x6000 ticks
      chunks = (period - 0x2000) >> 14;
      first = period - ((uint32_t)chunks << 14);
    }
    const int8_t sign = sps < 0 ? -1 : 1;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
      if (sign != stepSign) {
        stepSign = sign;
        if (sign > 0) PORTD |= _BV(PD7);
        else PORTD &= ~_BV(PD7);
      }
      stepFirst = first;
      stepChunks = chunks;
      if (!(TIMSK1 & _BV(OCIE1A))) {  // was stopped: first step one period from now
        stepLeft = chunks;
        OCR1A = TCNT1 + first;
        TIFR1 = _BV(OCF1A);
        TIMSK1 |= _BV(OCIE1A);
      }
    }
  }

  void enableMotor(bool on) override {
    if (on) PORTB &= ~_BV(PB0);
    else PORTB |= _BV(PB0);
  }

  bool homeSwitch() override {
    const bool high = PIND & _BV(PD6);
    return HOME_ACTIVE_LOW ? !high : high;
  }

  void armRefMark() override {
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
      refSeen = false;
      refArmed = true;
    }
  }
  bool refMark(int32_t& count) override {
    bool seen;
    uint16_t raw;
    ATOMIC_BLOCK(ATOMIC_RESTORESTATE) {
      seen = refSeen;
      raw = refRaw;
    }
    if (seen) {
      const int32_t full = scaleCount();
      count = full - (int16_t)(encLast_ - raw);
    }
    return seen;
  }

  void print(const char* line) override { Serial.println(line); }

  // Extends the 16-bit counts; must run at least every 32,767 counts (0.5 s at full speed).
  void poll() {
    scaleCount();
    stepCount();
  }

 private:
  float lastRate_ = 0;
  int32_t encFull_ = 0, stepFull_ = 0;
  uint16_t encLast_ = 0, stepLast_ = 0;
};

axis::Config makeConfig() {
  axis::Config c;
  c.letter = AXIS_LETTER;
  c.stepsPerMm = STEPS_PER_MM;
  c.motorDir = MOTOR_DIR;
  c.mmPerCount = MM_PER_COUNT;
  c.scaleDir = SCALE_DIR;
  c.minPos = MIN_POS_MM;
  c.maxPos = MAX_POS_MM;
  c.maxSpeed = MAX_SPEED_MM_S;
  c.speed = DEFAULT_SPEED_MM_S;
  c.accel = ACCEL_MM_S2;
  c.maxFollow = MAX_FOLLOW_ERR_MM;
  c.deadband = DEADBAND_COUNTS;
  c.holdBand = HOLD_BAND_COUNTS;
  c.settleMs = SETTLE_MS;
  c.trimSpeed = TRIM_SPEED_MM_S;
  c.maxTrims = MAX_TRIMS;
  c.homeDir = HOME_DIR;
  c.homeFast = HOME_FAST_MM_S;
  c.homeSlow = HOME_SLOW_MM_S;
  c.homeBackoff = HOME_BACKOFF_MM;
  c.homeMaxTravel = HOME_MAX_TRAVEL_MM;
  c.homePos = HOME_POS_MM;
  c.useRefMark = HOME_USE_REF_MARK;
  c.refSearch = REF_SEARCH_MM;
  c.refSpeed = REF_SEARCH_MM_S;
  c.requireHoming = REQUIRE_HOMING;
  return c;
}

AvrHal hal;
axis::Axis ax(hal, makeConfig());

// ---- serial: one line at a time; a line waits while the axis is busy ----

char line[64];
uint8_t lineLen = 0;
bool lineReady = false;
bool lineTooLong = false;

void pollSerial() {
  if (lineReady && ax.command(line)) {
    lineReady = false;
    lineLen = 0;
  }
  while (Serial.available()) {
    const int c = Serial.peek();
    if (c == '!') {  // realtime stop, also while a line is waiting
      Serial.read();
      ax.abort();
      continue;
    }
    if (lineReady) break;
    Serial.read();
    if (c == '\n' || c == '\r') {
      if (lineTooLong) {
        Serial.println(F("error: line too long"));
        lineTooLong = false;
        lineLen = 0;
      } else if (lineLen) {
        line[lineLen] = 0;
        lineReady = true;
      }
    } else if (lineLen < sizeof(line) - 1) {
      line[lineLen++] = (char)c;
    } else {
      lineTooLong = true;
    }
  }
}

uint32_t nextTick;

void setup() {
  Serial.begin(SERIAL_BAUD);

  // Inputs with pull-ups: scale A, B, Z and the home switch.
  DDRD &= ~(_BV(PD2) | _BV(PD3) | _BV(PD4) | _BV(PD6));
  PORTD |= _BV(PD2) | _BV(PD3) | _BV(PD4) | _BV(PD6);
  // STEP low, DIR high (= positive steps), EN high (motor off), LED off.
  DDRD |= _BV(PD5) | _BV(PD7);
  PORTD &= ~_BV(PD5);
  PORTD |= _BV(PD7);
  DDRB |= _BV(PB0) | _BV(PB5) | (TICK_PROBE ? _BV(PB4) : 0);
  PORTB |= _BV(PB0);
  PORTB &= ~_BV(PB5);

  // Timer1: normal mode, clk/8. The Arduino core set it up for PWM on D9/D10.
  TCCR1A = 0;
  TCCR1B = _BV(CS11);
  TIMSK1 = 0;

  // Scale A/B: interrupt on any change of INT0 and INT1.
  GPIOR0 = (PIND & 0x0C) >> 2;
  EICRA = _BV(ISC00) | _BV(ISC10);
  EIFR = _BV(INTF0) | _BV(INTF1);
  EIMSK = _BV(INT0) | _BV(INT1);
  // Scale Z: pin-change interrupt on D4 (PCINT20).
  PCMSK2 = _BV(PCINT20);
  PCIFR = _BV(PCIF2);
  PCICR |= _BV(PCIE2);

  ax.begin();
  nextTick = micros() + 1000;
}

void loop() {
  const uint32_t now = micros();
  if ((int32_t)(now - nextTick) >= 0) {
    if ((int32_t)(now - nextTick) > 2000) {  // fell behind: resynchronise, count it if moving
      nextTick = now;
      if (ax.busy()) ++ax.overruns;
    }
    nextTick += 1000;
    hal.poll();
#if TICK_PROBE
    PORTB |= _BV(PB4);
#endif
    ax.tick();
#if TICK_PROBE
    PORTB &= ~_BV(PB4);
#endif
    if (ax.homed() && ax.mode() == axis::Axis::IDLE) PORTB |= _BV(PB5);
    else PORTB &= ~_BV(PB5);
  }
  pollSerial();
}
