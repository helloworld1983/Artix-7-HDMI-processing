#!/usr/bin/env python3
import argparse
import os

from litex.gen import *
from litex.gen.genlib.resetsync import AsyncResetSynchronizer

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
            Instance("hdmi_io",
                i_clk100=ClockSignal(),
                i_clk200=ClockSignal("clk200"),

                io_hdmi_rx_cec=hdmi_in_pads.cec,
                o_hdmi_rx_hpa=hdmi_in_pads.hpa,
                i_hdmi_rx_scl=hdmi_in_pads.scl,
                io_hdmi_rx_sda=hdmi_in_pads.sda,
                o_hdmi_rx_txen=hdmi_in_pads.txen,
                i_hdmi_rx_clk=hdmi_in_clk,
                i_hdmi_rx=Cat(hdmi_in_data0, hdmi_in_data1, hdmi_in_data2),


                o_pixel_clk=pixel_clk,
                o_pixel_io_clk_x1=pixel_io_clk_x1,
                o_pixel_io_clk_x5=pixel_io_clk_x5,

                o_in_blank=blank,
                o_in_hsync=hsync,
                o_in_vsync=vsync,
                o_in_red=red,
                o_in_green=green,
                o_in_blue=blue
            )
        ]

        self.specials += [
            Instance("DVID_output",
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

        platform.add_source_dir("./input_src/")
        platform.add_source_dir("./output_src/")
        platform.add_source_dir("./")

        platform.add_period_constraint(hdmi_in_pads.clk_p, 6.7)


def main():
    platform = nexys_video.Platform()
    hdmi_loopback = HDMILoopback(platform)
    platform.build(hdmi_loopback)


if __name__ == "__main__":
    main()

