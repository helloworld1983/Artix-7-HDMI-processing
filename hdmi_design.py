#!/usr/bin/env python3
import argparse
import os

from litex.gen import *
from litex.gen.genlib.resetsync import AsyncResetSynchronizer
from litex.gen.fhdl.specials import Tristate

from litex.boards.platforms import nexys_video

from litex.soc.integration.builder import *


class _CRG(Module):
    def __init__(self, platform):
        self.clock_domains.cd_sys = ClockDomain()
        self.clock_domains.cd_clk200 = ClockDomain()

        clk100 = platform.request("clk100")
        rst = platform.request("cpu_reset")

        pll_locked = Signal()
        pll_fb = Signal()
        pll_sys = Signal()
        pll_clk200 = Signal()
        self.specials += [
            Instance("PLLE2_BASE",
                     p_STARTUP_WAIT="FALSE", o_LOCKED=pll_locked,

                     # VCO @ 800 MHz
                     p_REF_JITTER1=0.01, p_CLKIN1_PERIOD=10.0,
                     p_CLKFBOUT_MULT=8, p_DIVCLK_DIVIDE=1,
                     i_CLKIN1=clk100, i_CLKFBIN=pll_fb, o_CLKFBOUT=pll_fb,

                     # 100 MHz
                     p_CLKOUT0_DIVIDE=8, p_CLKOUT0_PHASE=0.0,
                     o_CLKOUT0=pll_sys,

                     # 200 MHz
                     p_CLKOUT3_DIVIDE=4, p_CLKOUT3_PHASE=0.0,
                     o_CLKOUT3=pll_clk200
            ),
            Instance("BUFG", i_I=pll_sys, o_O=self.cd_sys.clk),
            Instance("BUFG", i_I=pll_clk200, o_O=self.cd_clk200.clk),
            AsyncResetSynchronizer(self.cd_sys, ~pll_locked | ~rst),
            AsyncResetSynchronizer(self.cd_clk200, ~pll_locked | rst),
        ]

        reset_counter = Signal(4, reset=15)
        ic_reset = Signal(reset=1)
        self.sync.clk200 += \
            If(reset_counter != 0,
                reset_counter.eq(reset_counter - 1)
            ).Else(
                ic_reset.eq(0)
            )
        self.specials += Instance("IDELAYCTRL", i_REFCLK=ClockSignal("clk200"), i_RST=ic_reset)


class HDMILoopback(Module):
    def __init__(self, platform):
        self.submodules.crg = _CRG(platform)

        hdmi_in_pads = platform.request("hdmi_in")
        hdmi_out_pads = platform.request("hdmi_out")

        # input buffers
        hdmi_in_clk = Signal()
        hdmi_in_data0 = Signal()
        hdmi_in_data1 = Signal()
        hdmi_in_data2 = Signal()

        self.specials += [
            Instance("IBUFDS",
                p_IOSTANDARD="TMDS_33",
                i_I=hdmi_in_pads.clk_p,
                i_IB=hdmi_in_pads.clk_n,
                o_O=hdmi_in_clk),
            Instance("IBUFDS",
                p_IOSTANDARD="TMDS_33",
                i_I=hdmi_in_pads.data0_p,
                i_IB=hdmi_in_pads.data0_n,
                o_O=hdmi_in_data0),
            Instance("IBUFDS",
                p_IOSTANDARD="TMDS_33",
                i_I=hdmi_in_pads.data1_p,
                i_IB=hdmi_in_pads.data1_n,
                o_O=hdmi_in_data1),
            Instance("IBUFDS",
                p_IOSTANDARD="TMDS_33",
                i_I=hdmi_in_pads.data2_p,
                i_IB=hdmi_in_pads.data2_n,
                o_O=hdmi_in_data2),
        ]

        # output buffers
        hdmi_out_clk = Signal()
        hdmi_out_data0 = Signal()
        hdmi_out_data1 = Signal()
        hdmi_out_data2 = Signal()

        self.specials += [
            Instance("OBUFDS",
                p_IOSTANDARD="TMDS_33",
                p_SLEW="FAST",
                i_I=hdmi_out_clk,
                o_O=hdmi_out_pads.clk_p,
                o_OB=hdmi_out_pads.clk_n),
            Instance("OBUFDS",
                p_IOSTANDARD="TMDS_33",
                p_SLEW="FAST",
                i_I=hdmi_out_data0,
                o_O=hdmi_out_pads.data0_p,
                o_OB=hdmi_out_pads.data0_n),
            Instance("OBUFDS",
                p_IOSTANDARD="TMDS_33",
                p_SLEW="FAST",
                i_I=hdmi_out_data1,
                o_O=hdmi_out_pads.data1_p,
                o_OB=hdmi_out_pads.data1_n),
            Instance("OBUFDS",
                p_IOSTANDARD="TMDS_33",
                p_SLEW="FAST",
                i_I=hdmi_out_data2,
                o_O=hdmi_out_pads.data2_p,
                o_OB=hdmi_out_pads.data2_n),
        ]

        # edid
        sdat_in = Signal()
        sdat_oe = Signal()
        sdat_out = Signal()

        self.specials += Tristate(hdmi_in_pads.sda,
                                  sdat_out,
                                  sdat_oe,
                                  sdat_in)
        self.comb += [
            hdmi_in_pads.hpa.eq(1),
            hdmi_in_pads.txen.eq(1),
        ]
        self.specials += [
            Instance("edid_rom",
                i_clk=ClockSignal(),
                i_sclk=hdmi_in_pads.scl,
                i_sdat_in=sdat_in,
                o_sdat_oe=sdat_oe,
                o_sdat_out=sdat_out,
            )
        ]

        # hdmi input
        blank = Signal()
        hsync = Signal()
        vsync = Signal()
        red   = Signal(8)
        green = Signal(8)
        blue  = Signal(8)

        pixel_clk = Signal()
        pixel_io_clk_x1 = Signal()
        pixel_io_clk_x5 = Signal()

        self.specials += [
            Instance("hdmi_input",
                i_clk100=ClockSignal(),
                i_clk200=ClockSignal("clk200"),

                o_pixel_clk=pixel_clk,
                o_pixel_io_clk_x1=pixel_io_clk_x1,
                o_pixel_io_clk_x5=pixel_io_clk_x5,

                i_hdmi_in_clk=hdmi_in_clk,
                i_hdmi_in_ch0=hdmi_in_data2,
                i_hdmi_in_ch1=hdmi_in_data1,
                i_hdmi_in_ch2=hdmi_in_data0,

                o_raw_blank=blank,
                o_raw_hsync=hsync,
                o_raw_vsync=vsync,
                o_raw_ch0=blue,
                o_raw_ch1=green,
                o_raw_ch2=red
            )
        ]

        platform.add_source_dir("./input_src/")
        platform.add_period_constraint(hdmi_in_pads.clk_p, 6.7)

        # hdmi output
        self.specials += [
            Instance("hdmi_output",
                i_pixel_clk=pixel_clk,
                i_pixel_io_clk_x1=pixel_io_clk_x1,
                i_pixel_io_clk_x5=pixel_io_clk_x5,

                i_data_valid=1,
                i_vga_blank=blank,
                i_vga_hsync=hsync,
                i_vga_vsync=vsync,
                i_vga_red=red,
                i_vga_blue=blue,
                i_vga_green=green,

                o_tmds_out_clk=hdmi_out_clk,
                o_tmds_out_ch0=hdmi_out_data0,
                o_tmds_out_ch1=hdmi_out_data1,
                o_tmds_out_ch2=hdmi_out_data2
            )
        ]
        self.comb += hdmi_out_pads.scl.eq(1)
        platform.add_source_dir("./output_src/")

def main():
    platform = nexys_video.Platform()
    hdmi_loopback = HDMILoopback(platform)
    platform.build(hdmi_loopback)


if __name__ == "__main__":
    main()

