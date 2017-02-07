#!/usr/bin/env python3
import argparse
import os

from litex.gen import *
from litex.gen.genlib.resetsync import AsyncResetSynchronizer
from litex.gen.fhdl.specials import Tristate
from litex.gen.genlib.misc import WaitTimer

from litex.boards.platforms import nexys_video

from litex.soc.integration.builder import *

from litevideo.input.edid import EDID


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
                i_I=hdmi_in_pads.clk_p,
                i_IB=hdmi_in_pads.clk_n,
                o_O=hdmi_in_clk),
            Instance("IBUFDS",
                i_I=hdmi_in_pads.data0_p,
                i_IB=hdmi_in_pads.data0_n,
                o_O=hdmi_in_data0),
            Instance("IBUFDS",
                i_I=hdmi_in_pads.data1_p,
                i_IB=hdmi_in_pads.data1_n,
                o_O=hdmi_in_data1),
            Instance("IBUFDS",
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
                i_I=hdmi_out_clk,
                o_O=hdmi_out_pads.clk_p,
                o_OB=hdmi_out_pads.clk_n),
            Instance("OBUFDS",
                i_I=hdmi_out_data0,
                o_O=hdmi_out_pads.data0_p,
                o_OB=hdmi_out_pads.data0_n),
            Instance("OBUFDS",
                i_I=hdmi_out_data1,
                o_O=hdmi_out_pads.data1_p,
                o_OB=hdmi_out_pads.data1_n),
            Instance("OBUFDS",
                i_I=hdmi_out_data2,
                o_O=hdmi_out_pads.data2_p,
                o_OB=hdmi_out_pads.data2_n),
        ]

        # edid
        edid_rom = [
            0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00,
            0x04, 0x43, 0x07, 0xf2, 0x01, 0x00, 0x00, 0x00,
            0xff, 0x11, 0x01, 0x04, 0xa2, 0x4f, 0x00, 0x78,
            0x3e, 0xee, 0x91, 0xa3, 0x54, 0x4c, 0x99, 0x26,
            0x0f, 0x50, 0x54, 0x20, 0x00, 0x00, 0x01, 0x01,
            0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
            0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x02, 0x3a,
            0x80, 0x18, 0x71, 0x38, 0x2d, 0x40, 0x58, 0x2c,
            0x04, 0x05, 0x0f, 0x48, 0x42, 0x00, 0x00, 0x1e,
            0x01, 0x1d, 0x80, 0x18, 0x71, 0x1c, 0x16, 0x20,
            0x58, 0x2c, 0x25, 0x00, 0x0f, 0x48, 0x42, 0x00,
            0x00, 0x9e, 0x01, 0x1d, 0x00, 0x72, 0x51, 0xd0,
            0x1e, 0x20, 0x6e, 0x28, 0x55, 0x00, 0x0f, 0x48,
            0x42, 0x00, 0x00, 0x1e, 0x00, 0x00, 0x00, 0xfc,
            0x00, 0x48, 0x61, 0x6d, 0x73, 0x74, 0x65, 0x72,
            0x6b, 0x73, 0x0a, 0x20, 0x20, 0x20, 0x01, 0x74,
            0x02, 0x03, 0x18, 0x72, 0x47, 0x90, 0x85, 0x04,
            0x03, 0x02, 0x07, 0x06, 0x23, 0x09, 0x07, 0x07,
            0x83, 0x01, 0x00, 0x00, 0x65, 0x03, 0x0c, 0x00,
            0x10, 0x00, 0x8e, 0x0a, 0xd0, 0x8a, 0x20, 0xe0,
            0x2d, 0x10, 0x10, 0x3e, 0x96, 0x00, 0x1f, 0x09,
            0x00, 0x00, 0x00, 0x18, 0x8e, 0x0a, 0xd0, 0x8a,
            0x20, 0xe0, 0x2d, 0x10, 0x10, 0x3e, 0x96, 0x00,
            0x04, 0x03, 0x00, 0x00, 0x00, 0x18, 0x8e, 0x0a,
            0xa0, 0x14, 0x51, 0xf0, 0x16, 0x00, 0x26, 0x7c,
            0x43, 0x00, 0x1f, 0x09, 0x00, 0x00, 0x00, 0x98,
            0x8e, 0x0a, 0xa0, 0x14, 0x51, 0xf0, 0x16, 0x00,
            0x26, 0x7c, 0x43, 0x00, 0x04, 0x03, 0x00, 0x00,
            0x00, 0x98, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc9,
        ]
        self.submodules.edid = EDID(hdmi_in_pads, edid_rom)
        self.comb += [
            hdmi_in_pads.hpa.eq(1),
            hdmi_in_pads.txen.eq(1)
        ]

        # mmcm
        pix_clk_pll = Signal()
        pix5x_clk_pll = Signal()
        pix_clk = Signal()
        pix5x_clk = Signal()
        mmcm_fb = Signal()
        mmcm_locked = Signal()
        self.specials += [
            Instance("MMCME2_ADV",
                p_BANDWIDTH="OPTIMIZED", i_RST=0, o_LOCKED=mmcm_locked,

                # VCO
                p_REF_JITTER1=0.01, p_CLKIN1_PERIOD=6.7,
                p_CLKFBOUT_MULT_F=5.0, p_CLKFBOUT_PHASE=0.000, p_DIVCLK_DIVIDE=1,
                i_CLKIN1=hdmi_in_clk, i_CLKFBIN=mmcm_fb, o_CLKFBOUT=mmcm_fb,

                # CLK0
                p_CLKOUT0_DIVIDE_F=5.0, p_CLKOUT0_PHASE=0.000, o_CLKOUT0=pix_clk_pll,
                # CLK1
                p_CLKOUT1_DIVIDE=1, p_CLKOUT1_PHASE=0.000, o_CLKOUT1=pix5x_clk_pll
            ),
            Instance("BUFG", i_I=pix_clk_pll, o_O=pix_clk),
            Instance("BUFIO", i_I=pix5x_clk_pll, o_O=pix5x_clk),
        ]

        reset_timer = WaitTimer(256)
        self.submodules += reset_timer
        self.comb += reset_timer.wait.eq(mmcm_locked)

        # hdmi input
        blank = Signal()
        hsync = Signal()
        vsync = Signal()
        red   = Signal(8)
        green = Signal(8)
        blue  = Signal(8)

        self.specials += [
            Instance("hdmi_input",
                i_clk100=ClockSignal(),

                i_clk_pixel=pix_clk,
                i_clk_pixel_x1=pix_clk,
                i_clk_pixel_x5=pix5x_clk,
                i_ser_reset=~reset_timer.done,

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

        # hdmi output
        self.specials += [
            Instance("hdmi_output",
                i_pixel_clk=pix_clk,
                i_pixel_io_clk_x1=pix_clk,
                i_pixel_io_clk_x5=pix5x_clk,

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

