"""Draw the lin-log AFE schematic.  python3 schematic.py -> schematic.svg / schematic.png

Component values match sim/linlog_afe.py (the simulated design).  Parts marked * are
recommended for a real board but are not in the simulation.
"""
import os
import schemdraw
import schemdraw.elements as elm

schemdraw.use("matplotlib")


def vmid_tag(at, direction="right", lead=0.5):
    """Short wire plus a 'VMID' flag pointing away from the pin."""
    getattr(elm.Line().at(at), direction)(lead)
    getattr(elm.Tag(width=1.35), direction)().label("VMID", loc="center", fontsize=9)


def draw(path_svg, path_png):
    with schemdraw.Drawing(show=False) as d:
        d.config(unit=2.4, fontsize=11)

        # ---------------- U1: INA333 (pin numbers per TI SBOS445) ---------------------
        ina = elm.Ic(
            pins=[
                elm.IcPin(name="−IN", pin="2", side="left", slot="4/4", anchorname="INN"),
                elm.IcPin(name="RG", pin="1", side="left", slot="3/4", anchorname="RG1"),
                elm.IcPin(name="RG", pin="8", side="left", slot="2/4", anchorname="RG8"),
                elm.IcPin(name="+IN", pin="3", side="left", slot="1/4", anchorname="INP"),
                elm.IcPin(name="OUT", pin="6", side="right", anchorname="OUT"),
                elm.IcPin(name="V+", pin="7", side="top", anchorname="VP"),
                elm.IcPin(name="REF", pin="5", side="bottom", slot="1/2", anchorname="REF"),
                elm.IcPin(name="V−", pin="4", side="bottom", slot="2/2", anchorname="VN"),
            ],
            size=(4.4, 4.6), pinspacing=1.0, edgepadH=0.6, leadlen=0.8,
        ).at((0, 0)).label("U1\nINA333\nG = 5.016", loc="center", fontsize=11)

        # RG between pins 1 and 8
        elm.Line().at(ina.RG1).left(1.0)
        elm.Resistor().down().toy(ina.RG8).label("RG 24.9k\n0.1%", loc="top", ofst=0.1)
        elm.Line().right().tox(ina.RG8)

        elm.Vdd().at(ina.VP).label("3.0 V")
        elm.Ground().at(ina.VN)

        # ---------------- electrode inputs (protection / bias parts marked *) ----------
        x_in = ina.INN[0] - 6.4
        for pin, name, rp in [(ina.INN, "E−", "R2"), (ina.INP, "E+", "R1")]:
            elm.Dot(open=True).at((x_in, pin[1])).label(name, loc="left")
            elm.Resistor().right(2.4).label(f"{rp} 10k*", loc="top")
            node = elm.Dot()
            elm.Line().tox(pin)
            if name == "E−":
                elm.Resistor().at(node.center).up(1.9).label("10M*", loc="bottom")
                elm.Line().up(0.3)
                vmid_tag(d.here, "right", 0.3)
            else:
                elm.Resistor().at(node.center).down(1.9).label("10M*", loc="bottom")
                elm.Line().down(0.3)
                vmid_tag(d.here, "right", 0.3)

        # ---------------- INA output node -------------------------------------------
        elm.Line().at(ina.OUT).right(1.6)
        n_ina = elm.Dot()
        elm.Label().at((n_ina.center[0] - 0.75, n_ina.center[1] + 0.3)).label("INA_OUT", fontsize=9)

        # ---------------- U2B: lin-log stage ----------------------------------------
        elm.Line().at(n_ina.center).right(0.6)
        elm.Resistor().right(2.6).label("Rin 64.9k 0.1%", loc="top")
        n_sum = elm.Dot()
        oa2 = elm.Opamp(leads=True).anchor("in1").label("U2B\n½ LTC2064", loc="center",
                                                         ofst=(-0.4, 0), fontsize=8.5)
        elm.Line().at(n_sum.center).tox(oa2.in1)
        vmid_tag(oa2.in2, "left", 0.3)
        elm.Line().at(oa2.out).right(1.4)
        n_vout = elm.Dot()
        elm.Line().right(1.8)
        elm.Dot(open=True).label("VOUT\n→ ADC (≥16-bit)", loc="right")

        # feedback network: four parallel branches between summing node and VOUT
        xl, xr = n_sum.center[0], n_vout.center[0]
        y0 = n_sum.center[1]
        ys = [y0 + 1.7, y0 + 3.1, y0 + 4.5, y0 + 5.9]
        span = xr - xl
        xm = (xl + xr) / 2
        elm.Line().at(n_sum.center).toy(ys[-1])
        elm.Line().at(n_vout.center).toy(ys[-1])
        for y in ys[:3]:
            elm.Dot().at((xl, y))
            elm.Dot().at((xr, y))
        # Q3/Q4: conduct for negative input (VOUT above VMID): current VOUT -> summing node
        elm.Line().at((xl, ys[0])).right(span * 0.1)
        elm.Diode().right(span * 0.4).reverse().label("Q4", loc="bottom")
        elm.Diode().right(span * 0.4).reverse().label("Q3", loc="bottom")
        elm.Line().tox(xr)
        # Q1/Q2: conduct for positive input (VOUT below VMID): current summing node -> VOUT
        elm.Line().at((xl, ys[1])).right(span * 0.1)
        elm.Diode().right(span * 0.4).label("Q1", loc="bottom")
        elm.Diode().right(span * 0.4).label("Q2", loc="bottom")
        elm.Line().tox(xr)
        # Rf
        elm.Line().at((xl, ys[2])).tox(xm - 1.2)
        elm.Resistor().right(2.4).label("Rf 1M 0.1%", loc="top")
        elm.Line().tox(xr)
        # Cf
        elm.Line().at((xl, ys[3])).tox(xm - 0.6)
        elm.Capacitor().right(1.2).label("Cf 820p C0G", loc="top")
        elm.Line().tox(xr)

        # ---------------- U2A: DC servo (integrator driving REF) -----------------------
        x_ref, y_ref = ina.REF
        oa1 = elm.Opamp(leads=True).left().flip().anchor("out").at((x_ref + 0.8, y_ref - 4.0)) \
            .label("U2A\n½ LTC2064", loc="center", ofst=(-0.35, 0), fontsize=8.5)
        # output -> REF
        elm.Line().at(oa1.out).tox(x_ref)
        n_out1 = elm.Dot()
        elm.Line().toy((x_ref, y_ref))
        # Rs: INA_OUT down to the servo summing node
        xs = n_ina.center[0] - 0.9  # servo summing node, left of the Rs drop
        elm.Line().at(oa1.in1).tox(xs)
        n_s = elm.Dot()
        elm.Line().tox(n_ina.center)
        elm.Resistor().at(n_ina.center).down().toy(n_s.center).label("Rs 3.3M", loc="bottom")
        # Cs: summing node -> output (over the op-amp)
        xc = (x_ref + xs) / 2
        elm.Line().at(n_s.center).up(1.5)
        elm.Line().tox(xc + 0.7)
        elm.Capacitor().left(1.4).label("Cs 100n\n(1µ → 0.05 Hz)", loc="top")
        elm.Line().tox(x_ref)
        elm.Dot()
        vmid_tag(oa1.in2, "right", 0.5)

        # ---------------- VMID generator ------------------------------------------------
        gx, gy = xr + 1.4, y_ref - 2.0
        elm.Vdd().at((gx, gy)).label("3.0 V")
        elm.Resistor().at((gx, gy)).down(2.0).label("10M", loc="bottom")
        n_g = elm.Dot()
        elm.Resistor().down(2.0).label("10M", loc="bottom")
        elm.Ground()
        elm.Line().at(n_g.center).right(1.4)
        n_c = elm.Dot()
        elm.Capacitor().down(2.0).label("100n", loc="bottom")
        elm.Ground()
        elm.Line().at(n_c.center).right(0.5)
        elm.Tag(width=1.35).right().label("VMID", loc="center", fontsize=9)
        elm.Label().at((gx - 1.2, gy + 1.4)).label("VMID generator\n(feeds only high-Z inputs)",
                                                  halign="left", fontsize=9)

        # ---------------- inset: diode-connected transistor ------------------------------
        ix, iy = xl + 0.2, y_ref - 2.6
        q = elm.BjtNpn(circle=True).at((ix, iy)).anchor("base")
        elm.Line().at(q.base).up(1.0)
        elm.Line().tox(q.collector)
        elm.Line().toy(q.collector)
        elm.Label().at((q.emitter[0] + 1.0, (q.collector[1] + q.emitter[1]) / 2)).label("≡", fontsize=18)
        elm.Diode().down(1.6).at((q.emitter[0] + 2.0, q.collector[1] + 0.1))
        elm.Label().at((ix - 0.3, iy - 1.9)).label(
            "Q1–Q4: MMBT3904 with base\ntied to collector (anode = B/C,\ncathode = E); 2× MMDT3904 dual",
            halign="left", valign="top", fontsize=9)

        # ---------------- notes ----------------------------------------------------------
        nx, ny = x_in - 0.4, y_ref - 7.2
        elm.Label().at((nx, ny)).label(
            "Single 3.0 V supply, VMID = 1.5 V. U2 (LTC2064) supply pins: V+ = 3.0 V, V− = GND (not drawn). "
            "100 nF decoupling at every supply pin.\n"
            "Small-signal gain 77.3 V/V (37.7 dB). Linear (≤1 % error) to ±9.5 mV at 25 °C, "
            "±8.3 mV at 40 °C; logarithmic above.\n"
            "Servo high-pass 0.48 Hz (Cs 100 nF) or 0.048 Hz (Cs 1 µF); low-pass 194 Hz (Rf·Cf); "
            "system −3 dB to 166 Hz.\n"
            "No stage clips up to ±289 mV in-band, on top of ±300 mV electrode DC offset. "
            "Supply ≈ 53 µA (≈ 160 µW).\n"
            "* Not in the simulation: input protection and bias parts; size them to your "
            "safety standard (IEC 60601).",
            halign="left", valign="top", fontsize=9.5)

        d.save(path_svg)
        d.save(path_png, dpi=170)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    draw(os.path.join(here, "schematic.svg"), os.path.join(here, "schematic.png"))
