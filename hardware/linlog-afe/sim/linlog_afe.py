"""SPICE testbench for the lin-log biopotential front end (ngspice >= 42).

Run:  python3 linlog_afe.py            -> writes results/*.png and results/summary.txt
Needs: ngspice on PATH, numpy, matplotlib.

Signal chain (single 3.0 V supply, VMID = 1.5 V):
  electrodes -> INA333 (G1 = 5.016) -> stage 2: inverting lin-log amp (LTC2064 half B)
  DC servo: LTC2064 half A integrates INA output and drives INA REF (HPF ~0.48 Hz)

Model notes (what is and isn't "real" here):
  * Transistors: the vendor Gummel-Poon 2N3904 model (same die as MMBT3904 / MMDT3904).
  * INA333 and LTC2064 are behavioural: datasheet gain, GBW, rail clamps, and white
    noise injected through equivalent resistors (R = en^2 / 4kT).  No offsets, no 1/f
    (both parts are zero-drift, so their 1/f is negligible), no chopper ripple.
"""
import os
import subprocess
import tempfile
import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results")
os.makedirs(OUT, exist_ok=True)

K_B = 1.380649e-23
T_NOISE = 300.15  # ngspice default TNOM/TEMP = 27 C


def r_for_noise(en):
    """Resistor whose thermal noise equals en (V/rtHz) at 27 C."""
    return en ** 2 / (4 * K_B * T_NOISE)


# ---- datasheet values used in the behavioural models -------------------------------
INA_G = 1 + 100e3 / 24.9e3        # INA333: G = 1 + 100k/RG, RG = 24.9k -> 5.016
INA_ENI = 50e-9                   # INA333 input noise, V/rtHz
INA_ENO = 200e-9                  # INA333 output noise, V/rtHz (RTI = sqrt(eni^2+(eno/G)^2))
OA_GBW = 20e3                     # LTC2063/4 GBW, Hz
OA_AOL = 1e6                      # 120 dB open-loop gain (assumed, conservative for chopper)
OA_EN = 220e-9                    # LTC2063/4 voltage noise, V/rtHz (flat; zero-drift)

MODELS = f"""
.model Q3904 NPN(Is=6.734f Xti=3 Eg=1.11 Vaf=74.03 Bf=416.4 Ne=1.259 Ise=6.734f
+ Ikf=66.78m Xtb=1.5 Br=.7371 Nc=2 Isc=0 Ikr=0 Rc=1 Cjc=3.638p Mjc=.3085 Vjc=.75
+ Fc=.5 Cje=4.493p Mje=.2593 Vje=.75 Tr=239.5n Tf=301.2p Itf=.4 Vtf=4 Xtf=2 Rb=10)
.model DCLAMP D(Is=1e-15 N=0.05 EG=0.01 XTI=0)  ; op-amp rail clamp: keep temperature-independent

.subckt INA333 inp inn ref out
Rni inp inp_n {r_for_noise(INA_ENI):.6g}
Rno nno 0 {r_for_noise(INA_ENO):.6g}
Bg x 0 V = {INA_G:.6g}*(V(inp_n)-V(inn)) + V(ref) + V(nno)
Rbw x y 1k
Cbw y 0 3.18n
Bo out 0 V = max(min(V(y), 2.95), 0.05)
.ends

.subckt OPAMP inp inn out
Rn inp inp_n {r_for_noise(OA_EN):.6g}
G1 0 n1 inp_n inn 1u
R1 n1 0 {OA_AOL / 1e-6:.6g}
C1 n1 0 {1e-6 / (2 * np.pi * OA_GBW):.6g}
Vhi hi 0 2.95
Vlo lo 0 0.05
D1 n1 hi DCLAMP
D2 lo n1 DCLAMP
Bo out 0 V = V(n1)
.ends
"""


def netlist(rin, rf=1e6, cf=820e-12, servo=True, cs=100e-9, rs=3.3e6, src="DC 0 AC 1",
            offset_src="DC 0"):
    servo_block = (f"Rs ina ns {rs:g}\nCs ns ref {cs:g}\nXSV vmid ns ref OPAMP\n"
                   if servo else "Vref ref 0 1.5\n")
    return f"""* lin-log biopotential AFE
{MODELS}
VMID vmid 0 1.5
Vd vd 0 {src}
Voff voff 0 {offset_src}
Binp inp 0 V = V(vmid) + 0.5*(V(vd)+V(voff))
Binn inn 0 V = V(vmid) - 0.5*(V(vd)+V(voff))
XINA inp inn ref ina INA333
{servo_block}
Rin ina n2 {rin:g}
Rf n2 out {rf:g}
Cf n2 out {cf:g}
Q1 n2 n2 m1 Q3904
Q2 m1 m1 out Q3904
Q3 out out m2 Q3904
Q4 m2 m2 n2 Q3904
XS2 vmid n2 out OPAMP
"""


def run(cir_body, control):
    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, "t.cir")
        with open(path, "w") as f:
            f.write(cir_body + "\n.control\n" + control.replace("@TD@", td) + "\n.endc\n.end\n")
        p = subprocess.run(["ngspice", "-b", path], capture_output=True, text=True)
        if "rror" in p.stdout + p.stderr and "data" not in os.listdir(td):
            raise RuntimeError(p.stdout[-3000:] + p.stderr[-3000:])
        res = {}
        for fn in os.listdir(td):
            if fn.endswith(".dat"):
                res[fn[:-4]] = np.loadtxt(os.path.join(td, fn))
        if not res:
            raise RuntimeError(p.stdout[-3000:] + p.stderr[-3000:])
        return res


# ---- 1. DC transfer (in-band behaviour; servo replaced by REF = VMID) ----------------
def dc_transfer(rin, temps, vmax=0.3, step=0.1e-3):
    ctrl = ""
    for t in temps:
        ctrl += (f"option temp={t}\ndc Vd {-vmax} {vmax} {step}\n"
                 f"wrdata @TD@/dc_{t}.dat v(out)-v(vmid) v(ina)-v(vmid)\n")
    r = run(netlist(rin, servo=False), ctrl)
    out = {}
    for t in temps:
        d = r[f"dc_{t}"]
        out[t] = (d[:, 0], d[:, 1], d[:, 3])  # vin, vout-vmid, ina-vmid
    return out


def compression_points(vin, vout, levels=(0.01, 0.02, 0.05)):
    """Input (V) at which |vout| falls below the small-signal line by each level, per polarity."""
    i0 = np.argmin(np.abs(vin))
    sl = slice(i0 - 5, i0 + 6)
    g0 = np.polyfit(vin[sl], vout[sl], 1)[0]
    with np.errstate(invalid="ignore", divide="ignore"):
        err = 1 - vout / (g0 * vin)
    res = {}
    for lv in levels:
        pts = []
        for sign in (1, -1):
            m = sign * vin > 1e-6  # skip the (floating-point) zero sample
            a, e = sign * vin[m], err[m]
            o = np.argsort(a)
            a, e = a[o], e[o]
            k = np.argmax(e > lv)  # first grid point past the level; interpolate back
            pts.append(np.interp(lv, e[k - 1:k + 1], a[k - 1:k + 1]) if e[k] > lv else np.nan)
        res[lv] = tuple(pts)
    return g0, err, res


# ---- 2. AC response, 3. noise, 4. transient ----------------------------------------
def ac_response(rin, cs=100e-9):
    r = run(netlist(rin, cs=cs), "ac dec 50 0.005 20k\nwrdata @TD@/ac.dat v(out)")
    d = r["ac"]
    return d[:, 0], d[:, 1] + 1j * d[:, 2]


def noise(rin, cs=100e-9):
    ctrl = ("noise v(out) Vd dec 40 0.01 20k\nsetplot noise1\n"
            "wrdata @TD@/noise.dat onoise_spectrum inoise_spectrum")
    d = run(netlist(rin, cs=cs), ctrl)["noise"]
    return d[:, 0], d[:, 1], d[:, 3]


def ecg_like(t, hr=60.0, amp=2.0e-3):
    """Crude synthetic ECG (sum of Gaussians, McSharry-style P,Q,R,S,T), volts."""
    ph = (t * hr / 60.0) % 1.0
    waves = [(0.2, 0.15, 0.025), (0.37, -0.15, 0.01), (0.4, 1.0, 0.012),
             (0.43, -0.25, 0.01), (0.65, 0.3, 0.04)]
    return amp * sum(a * np.exp(-((ph - mu) ** 2) / (2 * s ** 2)) for mu, a, s in waves)


def transient(rin):
    fs = 2000.0
    t = np.arange(0, 12, 1 / fs)
    sig = ecg_like(t)
    # 1.5 s-5.5 s: large motion artefact, 40 mV peak at 1.5 Hz (6 whole cycles) + 120 mV spike at 4 s
    art = np.where((t > 1.5) & (t < 5.5), 40e-3 * np.sin(2 * np.pi * 1.5 * (t - 1.5)), 0.0)
    art += 120e-3 * np.exp(-((t - 4.0) ** 2) / (2 * 0.02 ** 2))
    vin = sig + art
    # electrode offset: +250 mV step at t = 7 s (e.g. lead re-contact)
    off = np.where(t > 7, 0.25, 0.0)
    pwl = " ".join(f"{a:.5f} {b:.6e}" for a, b in zip(t, vin))
    pwl_off = " ".join(f"{a:.5f} {b:.6e}" for a, b in zip(t, off))
    body = netlist(rin, src=f"PWL({pwl})", offset_src=f"PWL({pwl_off})")
    ctrl = ("tran 0.5m 12 0 0.5m\n"
            "wrdata @TD@/tr.dat v(out)-v(vmid) v(ina) v(ref) v(vd)")
    d = run(body, ctrl)["tr"]
    return d[:, 0], d[:, 1], d[:, 3], d[:, 5], d[:, 7], (t, vin, off)


# ---- 5. firmware linearisation: closed-form inverse of the lin-log stage --------------
Q_E = 1.602176634e-19


def inverse_model(vo, temp_c, is0, n, rin, rf=1e6, g1=INA_G, xti=3.0, eg=1.11, t0_c=25.0):
    """Estimate the differential input from Vout-VMID.

    Stage-2 summing node: G1*Vin/Rin = Vo/Rf + I_chain(Vo), with two identical
    junctions in series -> I_chain = Is(T) * (exp(|Vo| / (2 n VT)) - 1).
    Is(T) uses the standard SPICE junction law (XTI, EG) referenced to t0_c.
    """
    t, t0 = temp_c + 273.15, t0_c + 273.15
    vt = K_B * t / Q_E
    is_t = is0 * (t / t0) ** (xti / n) * np.exp((t / t0 - 1) * eg / (n * vt))
    a = np.abs(vo)
    return -np.sign(vo) * rin / g1 * (a / rf + is_t * np.expm1(a / (2 * n * vt)))


def fit_inverse(vin, vout, rin, temp_c=25.0, vmin=1e-3, vmax=0.28):
    from scipy.optimize import least_squares
    m = (np.abs(vin) >= vmin) & (np.abs(vin) <= vmax)

    def resid(p):
        est = inverse_model(vout[m], temp_c, 10 ** p[0], p[1], rin, t0_c=temp_c)
        return est / vin[m] - 1

    sol = least_squares(resid, x0=[-14.0, 1.0])
    return 10 ** sol.x[0], sol.x[1]


def main():
    temps = [15, 25, 40]
    lines = []

    # --- choose Rin: the largest Rin (highest gain) whose 1 % point stays >= 8 mV at 40 C
    lines.append("Rin sweep (Rf = 1 MOhm, 2x MMBT3904 per polarity), 1% compression point:")
    best = None
    for rin in [56e3, 59e3, 61.9e3, 64.9e3, 68e3, 75e3]:  # E96 values
        tr = dc_transfer(rin, temps, vmax=0.03, step=0.05e-3)
        row = []
        for tc in temps:
            g0, _, cp = compression_points(*tr[tc][:2])
            row.append((tc, g0, min(cp[0.01])))
        lines.append(f"  Rin={rin/1e3:5.1f}k  " + "  ".join(
            f"{tc}C: G={g:6.1f} 1%@{p*1e3:5.2f}mV" for tc, g, p in row))
        if row[-1][2] >= 8e-3 and (best is None or rin < best):  # 1 % point >= 8 mV at 40 C
            best = rin
    rin = best
    lines.append(f"\nSelected Rin = {rin/1e3:g} kOhm\n")

    # --- full transfer
    tr = dc_transfer(rin, temps)
    fig, ax = plt.subplots(1, 2, figsize=(12, 4.6))
    for tc in temps:
        vin, vout, vina = tr[tc]
        g0, err, cp = compression_points(vin, vout)
        lines.append(f"T={tc} C: small-signal gain {g0:.2f} V/V; compression points (+/-):")
        for lv, (p, n) in cp.items():
            lines.append(f"    {lv*100:.0f}%: +{p*1e3:.2f} mV / -{n*1e3:.2f} mV")
        for v in [8e-3, 20e-3, 50e-3, 100e-3, 200e-3, 300e-3]:
            k = np.argmin(np.abs(vin - v))
            lines.append(f"    Vin={v*1e3:5.0f} mV -> Vout-VMID={vout[k]:+.3f} V, INA out-VMID={vina[k]:+.3f} V")
        ax[0].plot(vin * 1e3, vout, label=f"{tc} °C")
        m = (np.abs(vin) <= 0.03) & (np.abs(vin) > 0.3e-3)
        ax[1].plot(vin[m] * 1e3, err[m] * 100, label=f"{tc} °C")
    # firmware inverse: fit (Is, n) once at 25 C, then predict other temperatures from T alone
    is0, n_fit = fit_inverse(tr[25][0], tr[25][1], rin)
    lines.append(f"Inverse model fit @25 C: Is = {is0:.3e} A, n = {n_fit:.4f}")
    for tc in temps:
        vin, vout, _ = tr[tc]
        m = (np.abs(vin) >= 1e-3) & (np.abs(vin) <= 0.28)
        e_t = inverse_model(vout[m], tc, is0, n_fit, rin) / vin[m] - 1
        e_25 = inverse_model(vout[m], 25.0, is0, n_fit, rin) / vin[m] - 1
        lines.append(f"    {tc} C, 1-280 mV: max |error| {np.max(np.abs(e_t))*100:.2f} % with measured T, "
                     f"{np.max(np.abs(e_25))*100:.1f} % if T is ignored (assumed 25 C)")
    g25 = compression_points(*tr[25][:2])[0]
    vv = np.linspace(-0.3, 0.3, 601)
    ax[0].plot(vv * 1e3, np.clip(g25 * vv, -1.45, 1.45), "k:", lw=1, label="ideal linear (25 °C)")
    ax[0].axvspan(-8, 8, color="0.9", zorder=-1)
    ax[0].set(xlabel="Differential input (mV)", ylabel="Vout − VMID (V)",
              title="DC transfer (in-band)", ylim=(-1.6, 1.6))
    ax[0].grid(alpha=0.3); ax[0].legend()
    ax[1].axhline(1, color="k", lw=0.8, ls="--")
    ax[1].axvline(8, color="k", lw=0.8, ls=":"); ax[1].axvline(-8, color="k", lw=0.8, ls=":")
    ax[1].set(xlabel="Differential input (mV)", ylabel="Compression vs small-signal line (%)",
              title="Linearity error, ±30 mV", ylim=(-0.5, 10))
    ax[1].grid(alpha=0.3); ax[1].legend()
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "dc_transfer.png"), dpi=130)

    # log-axis view of the compressive region
    fig, ax = plt.subplots(figsize=(6.2, 4.4))
    for tc in temps:
        vin, vout, _ = tr[tc]
        m = vin > 0.2e-3
        ax.semilogx(vin[m] * 1e3, -vout[m], label=f"{tc} °C")
    ax.axvline(8, color="k", lw=0.8, ls=":")
    ax.set(xlabel="Input (mV, log scale)", ylabel="|Vout − VMID| (V)",
           title="Linear below the knee, logarithmic above")
    ax.grid(alpha=0.3, which="both"); ax.legend()
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "dc_transfer_log.png"), dpi=130)

    # --- AC
    fig, ax = plt.subplots(figsize=(6.2, 4.4))
    for cs, lab in [(100e-9, "Cs = 100 nF (monitor, 0.48 Hz)"), (1e-6, "Cs = 1 µF (diagnostic, 0.048 Hz)")]:
        f, h = ac_response(rin, cs)
        gdb = 20 * np.log10(np.abs(h))
        ax.semilogx(f, gdb, label=lab)
        mid = gdb[np.argmin(np.abs(f - 10))]
        band = f[gdb > mid - 3]
        lines.append(f"AC ({lab}): midband {mid:.2f} dB ({10**(mid/20):.1f} V/V), "
                     f"-3 dB {band.min():.3g} Hz .. {band.max():.3g} Hz")
    ax.set(xlabel="Frequency (Hz)", ylabel="Gain (dB)", title="Small-signal response",
           ylim=(0, 45))
    ax.grid(alpha=0.3, which="both"); ax.legend()
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "ac_response.png"), dpi=130)

    # --- noise
    f, on, inn = noise(rin)
    fa, ha = ac_response(rin)
    gmid = np.abs(ha[np.argmin(np.abs(fa - 10))])

    def integ(fl, fh, spec):
        m = (f >= fl) & (f <= fh)
        return np.sqrt(np.trapezoid(spec[m] ** 2, f[m]))

    out_rms = integ(0.01, 20e3, on)
    lines.append(f"Noise: input density at 10 Hz = {np.interp(10, f, inn)*1e9:.1f} nV/rtHz")
    lines.append(f"Noise: total output 0.01 Hz-20 kHz = {out_rms*1e6:.1f} uVrms -> "
                 f"RTI {out_rms/gmid*1e6:.2f} uVrms (~{6.6*out_rms/gmid*1e6:.1f} uVpp @6.6x)")
    lines.append(f"Noise: RTI brick-wall 0.5-150 Hz = {integ(0.5, 150, inn)*1e6:.2f} uVrms")
    lines.append("       (white-noise models only; add electrode/skin noise and input-protection R noise)")
    fig, ax = plt.subplots(figsize=(6.2, 4.4))
    ax.loglog(f, inn * 1e9)
    ax.set(xlabel="Frequency (Hz)", ylabel="Input-referred noise (nV/√Hz)",
           title="Input-referred noise density", xlim=(0.1, 2e3), ylim=(10, 1e4))
    ax.grid(alpha=0.3, which="both")
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "noise.png"), dpi=130)

    # --- transient
    tt, vout, vina, vref, vd, (t0, vin0, off0) = transient(rin)
    lines.append(f"Transient: max |Vout-VMID| = {np.max(np.abs(vout)):.3f} V; "
                 f"INA out range {vina.min():.3f}..{vina.max():.3f} V; REF range {vref.min():.3f}..{vref.max():.3f} V")
    fig, ax = plt.subplots(3, 1, figsize=(11, 7.5), sharex=True)
    ax[0].plot(t0, vin0 * 1e3, lw=0.8, label="differential signal")
    ax[0].plot(t0, off0 * 1e3 / 10, lw=0.8, label="electrode DC offset ÷10")
    ax[0].set(ylabel="Input (mV)"); ax[0].legend(loc="upper right"); ax[0].grid(alpha=0.3)
    ax[1].plot(tt, vina, lw=0.8, label="INA333 out")
    ax[1].plot(tt, vref, lw=0.8, label="servo → REF")
    ax[1].axhline(2.95, color="r", lw=0.6, ls="--"); ax[1].axhline(0.05, color="r", lw=0.6, ls="--")
    ax[1].set(ylabel="V"); ax[1].legend(loc="upper right"); ax[1].grid(alpha=0.3)
    ax[2].plot(tt, vout, lw=0.8)
    ax[2].axhline(1.45, color="r", lw=0.6, ls="--"); ax[2].axhline(-1.45, color="r", lw=0.6, ls="--")
    ax[2].set(xlabel="Time (s)", ylabel="Vout − VMID (V)"); ax[2].grid(alpha=0.3)
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "transient.png"), dpi=130)

    with open(os.path.join(OUT, "summary.txt"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
