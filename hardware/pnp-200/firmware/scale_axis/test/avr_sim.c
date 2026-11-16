// avr_sim.c: runs the compiled scale_axis firmware in simavr (a cycle-accurate
// ATmega328P simulator) with a simulated motor and glass scale on its pins.
//
// Checks: boot banner, homing on the reference mark, closed-loop moves at
// 150 mm/s, and how fast the scale can count while the motor steps at full
// rate. Build the sketch with TICK_PROBE 1 in config.h to also measure how
// long each control tick takes (D12).
//
//   sudo apt install simavr libsimavr-dev
//   gcc -O2 -Wall -o avr_sim avr_sim.c -lsimavr -lm
//   ./avr_sim path/to/scale_axis.ino.elf
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <simavr/avr_ioport.h>
#include <simavr/avr_uart.h>
#include <simavr/sim_avr.h>
#include <simavr/sim_cycle_timers.h>
#include <simavr/sim_elf.h>

static avr_t* avr;
static avr_irq_t *pinA, *pinB, *pinZ, *pinHome, *uartIn;

// motor: counts STEP pulses on D5, direction from D7
static long steps = 0;
static int dirHigh = 1;
// carriage and scale
static double x = 10.0;       // carriage, mm (true position)
static const double X0 = 10;  // carriage position at steps == 0
static long count = 0, countOrigin;
static int encState = 0;
static int coupled = 1;       // 1: the scale follows the carriage; 0: free-running generator
static double genRate = 0;    // generator counts per second
static avr_cycle_count_t genNext = 0;
static long genCount = 0;
// control-tick probe on D12 (PB4)
static avr_cycle_count_t tickStart = 0;
static double tickMax = 0, tickSum = 0;
static long tickN = 0;
// serial lines from the firmware
static char lineBuf[256];
static int lineLen = 0;
static char lines[64][256];
static int nLines = 0;

static const int SEQ[4] = {0, 1, 3, 2};  // A | B << 1 while counting up

// simavr 1.6 re-raises pull-up inputs as high on every PORTD write, which
// would override an external driver; declaring the driven level as "external"
// stops that.
static uint8_t extValue = 1 << 6;
static void drivePin(avr_irq_t* irq, int bit, int v) {
  extValue = v ? (extValue | (1 << bit)) : (extValue & ~(1 << bit));
  avr_ioport_external_t e;
  e.name = 'D';
  e.mask = (1 << 2) | (1 << 3) | (1 << 4) | (1 << 6);
  e.value = extValue;
  avr_ioctl(avr, AVR_IOCTL_IOPORT_SET_EXTERNAL('D'), &e);
  avr_raise_irq(irq, v);
}

static void setEncoder(long c) {
  int s = SEQ[((c % 4) + 4) % 4];
  if (s == encState) return;
  if ((s & 1) != (encState & 1)) drivePin(pinA, 2, s & 1);
  if ((s & 2) != (encState & 2)) drivePin(pinB, 3, (s >> 1) & 1);
  encState = s;
}

static void stepCb(avr_irq_t* irq, uint32_t value, void* p) {
  (void)irq, (void)p;
  if (value) steps += dirHigh ? 1 : -1;
}
static void dirCb(avr_irq_t* irq, uint32_t value, void* p) {
  (void)irq, (void)p;
  dirHigh = value ? 1 : 0;
}
static void probeCb(avr_irq_t* irq, uint32_t value, void* p) {
  (void)irq, (void)p;
  if (value) {
    tickStart = avr->cycle;
  } else if (tickStart) {
    double us = (avr->cycle - tickStart) / 16.0;
    if (us > tickMax) tickMax = us;
    tickSum += us;
    tickN++;
  }
}
static void uartCb(avr_irq_t* irq, uint32_t value, void* p) {
  (void)irq, (void)p;
  char c = (char)value;
  if (c == '\n') {
    if (lineLen && lineBuf[lineLen - 1] == '\r') lineLen--;
    lineBuf[lineLen] = 0;
    strcpy(lines[nLines++ % 64], lineBuf);
    printf("    << %s\n", lineBuf);
    lineLen = 0;
  } else if (lineLen < 255) {
    lineBuf[lineLen++] = c;
  }
}

// Carriage: follows the motor with a 1 ms lag and a 20 um pulley wobble.
// Reference marks every 50 mm from 3.217 mm; home switch below -1 mm.
static avr_cycle_count_t plantCb(avr_t* a, avr_cycle_count_t when, void* p) {
  (void)a, (void)p;
  if (coupled) {
    double xm = X0 + steps / 160.0 + 0.02 * sin(2 * M_PI * (steps / 160.0) / 40.0);
    x += (xm - x) * (2e-6 / 1e-3);
    long c = (long)floor(x / 0.005) - countOrigin;
    while (c != count) {
      count += c > count ? 1 : -1;
      setEncoder(count);
    }
    static int zLast = 0, hLast = 1;
    int z = fmod(x - 3.217 + 1000.0, 50.0) < 0.005, h = !(x < -1.0);
    if (z != zLast) drivePin(pinZ, 4, zLast = z);
    if (h != hLast) drivePin(pinHome, 6, hLast = h);
  }
  return when + 32;  // every 2 us
}

// Free-running quadrature with exactly spaced edges.
static avr_cycle_count_t genCb(avr_t* a, avr_cycle_count_t when, void* p) {
  (void)a, (void)when, (void)p;
  if (coupled || genRate <= 0) return 0;
  setEncoder(++genCount);
  genNext += (avr_cycle_count_t)(16e6 / genRate);
  return genNext;
}

static void runFor(double seconds) {
  avr_cycle_count_t end = avr->cycle + (avr_cycle_count_t)(seconds * 16e6);
  while (avr->cycle < end) {
    int st = avr_run(avr);
    if (st == cpu_Done || st == cpu_Crashed) {
      printf("CPU stopped (%d)\n", st);
      exit(1);
    }
  }
}

// Sends a line and waits for "ok" or "error".
static const char* cmd(const char* s, double timeout) {
  int start = nLines;
  printf("    >> %s\n", s);
  for (const char* c = s; *c; c++) {
    avr_raise_irq(uartIn, (uint8_t)*c);
    runFor(0.0001);
  }
  avr_raise_irq(uartIn, '\n');
  avr_cycle_count_t end = avr->cycle + (avr_cycle_count_t)(timeout * 16e6);
  while (avr->cycle < end) {
    avr_run(avr);
    for (int i = start; i < nLines; i++) {
      const char* l = lines[i % 64];
      if (!strncmp(l, "ok", 2) || !strncmp(l, "error", 5)) return l;
    }
  }
  return "timeout";
}

static const char* lastLine(char first) {
  for (int i = nLines - 1; i >= 0 && i >= nLines - 64; i--)
    if (lines[i % 64][0] == first) return lines[i % 64];
  return "";
}
static double lastPos(void) { return atof(lastLine('X') + 2); }
static long lastCount(void) {
  const char* c = strstr(lastLine('X'), " C:");
  return c ? atol(c + 3) : -999999;
}
static void resetTicks(void) { tickMax = tickSum = 0, tickN = 0; }

static int fails = 0;
#define EXPECT(cond, ...)       \
  do {                          \
    if (!(cond)) {              \
      fails++;                  \
      printf("  FAIL: ");       \
      printf(__VA_ARGS__);      \
      printf("\n");             \
    }                           \
  } while (0)

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("usage: %s scale_axis.ino.elf\n", argv[0]);
    return 2;
  }
  elf_firmware_t f = {{0}};
  if (elf_read_firmware(argv[1], &f)) {
    printf("cannot read %s\n", argv[1]);
    return 2;
  }
  avr = avr_make_mcu_by_name("atmega328p");
  avr_init(avr);
  avr->frequency = 16000000;
  avr_load_firmware(avr, &f);

  uint32_t flags = 0;
  avr_ioctl(avr, AVR_IOCTL_UART_GET_FLAGS('0'), &flags);
  flags &= ~AVR_UART_FLAG_STDIO;
  avr_ioctl(avr, AVR_IOCTL_UART_SET_FLAGS('0'), &flags);
  avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_OUTPUT), uartCb, NULL);
  uartIn = avr_io_getirq(avr, AVR_IOCTL_UART_GETIRQ('0'), UART_IRQ_INPUT);
  avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 5), stepCb, NULL);
  avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 7), dirCb, NULL);
  avr_irq_register_notify(avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('B'), 4), probeCb, NULL);
  pinA = avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 2);
  pinB = avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 3);
  pinZ = avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 4);
  pinHome = avr_io_getirq(avr, AVR_IOCTL_IOPORT_GETIRQ('D'), 6);
  // Real pins interrupt only on a change: ignore repeated raises of one level.
  pinA->flags |= IRQ_FLAG_FILTERED;
  pinB->flags |= IRQ_FLAG_FILTERED;
  pinZ->flags |= IRQ_FLAG_FILTERED;
  pinHome->flags |= IRQ_FLAG_FILTERED;
  countOrigin = (long)floor(x / 0.005);
  drivePin(pinA, 2, 1), drivePin(pinA, 2, 0);
  drivePin(pinB, 3, 1), drivePin(pinB, 3, 0);
  drivePin(pinZ, 4, 1), drivePin(pinZ, 4, 0);
  drivePin(pinHome, 6, 1);
  avr_cycle_timer_register(avr, 32, plantCb, NULL);

  printf("boot\n");
  runFor(0.2);
  EXPECT(nLines > 0 && strstr(lines[0], "ready"), "no banner");

  printf("homing on the reference mark\n");
  const char* r = cmd("G28", 20);
  EXPECT(!strcmp(r, "ok"), "G28 -> %s", r);
  cmd("M114", 1);
  printf("  carriage %.4f mm, firmware %.4f mm (mark at 3.217 mm)\n", x, lastPos());
  EXPECT(fabs((x - 3.217) - lastPos()) < 0.011, "home offset");

  printf("closed-loop moves at 150 mm/s\n");
  resetTicks();
  const double targets[] = {150, 20.123, 200, 75.5};
  for (int i = 0; i < 4; i++) {
    char b[48];
    snprintf(b, sizeof b, "G0 X%.3f F9000", targets[i]);
    r = cmd(b, 2);
    EXPECT(!strcmp(r, "ok"), "%s -> %s", b, r);
    r = cmd("M400", 5);
    EXPECT(!strcmp(r, "ok"), "M400 -> %s", r);
    cmd("M114", 1);
    printf("  target %.3f: firmware %.4f, carriage %.4f\n", targets[i], lastPos(), x - 3.217);
    EXPECT(fabs(x - 3.217 - targets[i]) < 0.011, "target %.3f", targets[i]);
  }
  if (tickN) printf("  control tick: mean %.0f us, max %.0f us (budget 1000 us)\n", tickSum / tickN, tickMax);
  cmd("M122", 1);

  printf("count rate (open loop, motor at 24,000 steps/s, scale driven separately)\n");
  coupled = 0;
  genCount = count;
  cmd("M901 S0", 1);
  cmd("G92 X0", 1);
  const double rates[] = {30000, 50000, 60000, 70000, 80000, 90000};
  for (int i = 0; i < 6; i++) {
    cmd("M114", 1);
    long c0 = lastCount(), g0 = genCount;
    cmd("G0 X150 F9000", 1);
    genRate = rates[i];
    genNext = avr->cycle + 100;
    avr_cycle_timer_register(avr, 100, genCb, NULL);
    resetTicks();
    runFor(0.5);
    genRate = 0;
    runFor(0.01);
    cmd("M400", 3);
    cmd("M114", 1);
    long got = lastCount() - c0, want = genCount - g0;
    printf("  %6.0f counts/s: counted %ld of %ld", rates[i], got, want);
    if (tickN) printf(", tick mean %.0f max %.0f us", tickSum / tickN, tickMax);
    printf("\n");
    if (rates[i] <= 60000) EXPECT(got == want, "lost counts at %.0f/s", rates[i]);
    cmd("G0 X0 F9000", 1);
    cmd("M400", 3);
  }
  cmd("M122", 1);
  printf(fails ? "%d FAILED\n" : "all passed\n", fails);
  return fails ? 1 : 0;
}
