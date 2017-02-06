----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
--
-- Module Name: hdmi_io - Behavioral
--
-- Description: Wrapper for input and output components of HDMI data stream
--
------------------------------------------------------------------------------------
-- The MIT License (MIT)
--
-- Copyright (c) 2015 Michael Alan Field
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
------------------------------------------------------------------------------------
----- Want to say thanks? ----------------------------------------------------------
------------------------------------------------------------------------------------
--
-- This design has taken many hours - with the industry metric of 30 lines
-- per day, it is equivalent to about 6 months of work. I'm more than happy
-- to share it if you can make use of it. It is released under the MIT license,
-- so you are not under any onus to say thanks, but....
--
-- If you what to say thanks for this design how about trying PayPal?
--  Educational use - Enough for a beer
--  Hobbyist use    - Enough for a pizza
--  Research use    - Enough to take the family out to dinner
--  Commercial use  - A weeks pay for an engineer (I wish!)
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity hdmi_io is
    port (
        clk100        : in STD_LOGIC;

        -------------------------------
        --HDMI input signals
        -------------------------------
        hdmi_rx_cec   : inout std_logic;
        hdmi_rx_hpa   : out   std_logic;
        hdmi_rx_scl   : in    std_logic;
        hdmi_rx_sda   : inout std_logic;
        hdmi_rx_txen  : out   std_logic;
        hdmi_rx_clk   : in    std_logic;
        hdmi_rx       : in    std_logic_vector(2 downto 0);

        -------------
        -- HDMI out
        -------------
        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk   : out   std_logic;
        hdmi_tx_hpd   : in    std_logic;
        hdmi_tx_rscl  : inout std_logic;
        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx       : out   std_logic_vector(2 downto 0);

        pixel_clk : out std_logic;
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_blank  : out std_logic;
        in_hsync  : out std_logic;
        in_vsync  : out std_logic;
        in_red    : out std_logic_vector(7 downto 0);
        in_green  : out std_logic_vector(7 downto 0);
        in_blue   : out std_logic_vector(7 downto 0);

        -----------------------------------
        -- VGA data to be converted to HDMI
        -----------------------------------
        out_blank : in  std_logic;
        out_hsync : in  std_logic;
        out_vsync : in  std_logic;
        out_red   : in  std_logic_vector(7 downto 0);
        out_green : in  std_logic_vector(7 downto 0);
        out_blue  : in  std_logic_vector(7 downto 0)
    );
end entity;

architecture Behavioral of hdmi_io is

    signal raw_blank : std_logic;
    signal raw_hsync : std_logic;
    signal raw_vsync : std_logic;
    signal raw_ch2   : std_logic_vector(7 downto 0);  -- B or Cb
    signal raw_ch1   : std_logic_vector(7 downto 0);  -- G or Y
    signal raw_ch0   : std_logic_vector(7 downto 0);  -- R or Cr

    -- Clocks for the pixel clock domain
    signal pixel_clk_i     : std_logic;
    signal pixel_io_clk_x1 : std_logic;
    signal pixel_io_clk_x5 : std_logic;

begin

    pixel_clk <= pixel_clk_i;
    hdmi_rx_hpa  <= '1';
    hdmi_rx_txen <= '1';
    hdmi_rx_cec  <= 'Z';

i_edid_rom: entity work.edid_rom  port map (
             clk      => clk100,
             sclk_raw => hdmi_rx_scl,
             sdat_raw => hdmi_rx_sda,
             edid_debug => open);

i_hdmi_input : entity work.hdmi_input port map (
        system_clk      => clk100,
        -- Pixel and serializer clocks
        pixel_clk       => pixel_clk_i,
        pixel_io_clk_x1 => pixel_io_clk_x1,
        pixel_io_clk_x5 => pixel_io_clk_x5,
        --- HDMI input signals
        hdmi_in_clk   => hdmi_rx_clk,
        hdmi_in_ch0   => hdmi_rx(2), -- FIXME
        hdmi_in_ch1   => hdmi_rx(1), -- FIXME
        hdmi_in_ch2   => hdmi_rx(0), -- FIXME
        -- are the HDMI symbols in sync?
        symbol_sync   => open,
        pll_locked    => open,
        -- VGA internal Signals
        raw_blank     => raw_blank,
        raw_hsync     => raw_hsync,
        raw_vsync     => raw_vsync,
        raw_ch2       => raw_ch2,
        raw_ch1       => raw_ch1,
        raw_ch0       => raw_ch0
    );

    -----------------------------------------
    -- Colour space conversion yet to be done
    -----------------------------------------
    in_blank <= raw_blank;
    in_hsync <= raw_hsync;
    in_vsync <= raw_vsync;
    in_blue  <= raw_ch2;
    in_green <= raw_ch1;
    in_red   <= raw_ch0;

------------------------------------------------
-- Outputting video data
-----------------------------------------------
i_DVID_output: entity work.DVID_output port map (
        pixel_clk       => pixel_clk_i,
        pixel_io_clk_x1 => pixel_io_clk_x1,
        pixel_io_clk_x5 => pixel_io_clk_x5,

        data_valid      => '1',
        -- VGA Signals
        vga_blank     => out_blank,
        vga_hsync     => out_hsync,
        vga_vsync     => out_vsync,
        vga_red       => out_red,
        vga_blue      => out_blue,
        vga_green     => out_green,

        --- HDMI out
        tmds_out_clk  => hdmi_tx_clk,
        tmds_out_ch0  => hdmi_tx(0),
        tmds_out_ch1  => hdmi_tx(1),
        tmds_out_ch2  => hdmi_tx(2)
    );

    -----------------------------
    -- Other HDMI control signals
    -----------------------------
    hdmi_tx_rsda  <= 'Z';
    hdmi_tx_cec   <= 'Z';
    hdmi_tx_rscl  <= '1';

end Behavioral;
