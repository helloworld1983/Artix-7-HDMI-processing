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
        -- Control signals
        -------------------------------
        clock_locked   : out std_logic;
        data_synced    : out std_logic;

        -------------------------------
        --HDMI input signals
        -------------------------------
        hdmi_rx_cec   : inout std_logic;
        hdmi_rx_hpa   : out   std_logic;
        hdmi_rx_scl   : in    std_logic;
        hdmi_rx_sda   : inout std_logic;
        hdmi_rx_txen  : out   std_logic;
        hdmi_rx_clk_n : in    std_logic;
        hdmi_rx_clk_p : in    std_logic;
        hdmi_rx_n     : in    std_logic_vector(2 downto 0);
        hdmi_rx_p     : in    std_logic_vector(2 downto 0);

        -------------
        -- HDMI out
        -------------
        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk_n : out   std_logic;
        hdmi_tx_clk_p : out   std_logic;
        hdmi_tx_hpd   : in    std_logic;
        hdmi_tx_rscl  : inout std_logic;
        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx_p     : out   std_logic_vector(2 downto 0);
        hdmi_tx_n     : out   std_logic_vector(2 downto 0);

        pixel_clk : out std_logic;
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_hdmi_detected : out std_logic;
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

    signal adp_data_valid      : std_logic;
    signal adp_header_bit      : std_logic;
    signal adp_frame_bit       : std_logic;
    signal adp_subpacket0_bits : std_logic_vector(1 downto 0);
    signal adp_subpacket1_bits : std_logic_vector(1 downto 0);
    signal adp_subpacket2_bits : std_logic_vector(1 downto 0);
    signal adp_subpacket3_bits : std_logic_vector(1 downto 0);
    signal is_interlaced_i     : std_logic;
    signal is_second_field_i   : std_logic;


    signal input_is_YCbCr      : std_Logic;
    signal input_is_422        : std_logic;
    signal input_is_sRGB       : std_Logic;

    signal raw_blank : std_logic;
    signal raw_hsync : std_logic;
    signal raw_vsync : std_logic;
    signal raw_ch2   : std_logic_vector(7 downto 0);  -- B or Cb
    signal raw_ch1   : std_logic_vector(7 downto 0);  -- G or Y
    signal raw_ch0   : std_logic_vector(7 downto 0);   -- R or Cr

    signal fourfourfour_blank : std_logic;
    signal fourfourfour_hsync : std_logic;
    signal fourfourfour_vsync : std_logic;
    signal fourfourfour_U     : std_logic_vector(11 downto 0);
    signal fourfourfour_V     : std_logic_vector(11 downto 0);
    signal fourfourfour_W     : std_logic_vector(11 downto 0);

    signal rgb_blank : std_logic;
    signal rgb_hsync : std_logic;
    signal rgb_vsync : std_logic;
    signal rgb_R     : std_logic_vector(11 downto 0);
    signal rgb_G     : std_logic_vector(11 downto 0);  -- G or Y
    signal rgb_B     : std_logic_vector(11 downto 0);   -- R or Cr

    -- Clocks for the pixel clock domain
    signal pixel_clk_i     : std_logic;
    signal pixel_io_clk_x1 : std_logic;
    signal pixel_io_clk_x5 : std_logic;

    -- The serial data
    signal tmds_in_clk  : std_logic;
    signal tmds_in_ch0  : std_logic;
    signal tmds_in_ch1  : std_logic;
    signal tmds_in_ch2  : std_logic;

    signal tmds_out_clk : std_logic;
    signal tmds_out_ch0 : std_logic;
    signal tmds_out_ch1 : std_logic;
    signal tmds_out_ch2 : std_logic;

    signal detect_sr : std_logic_vector(7 downto 0) := (others => '0');
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

    ---------------------
    -- Input buffers
    ---------------------
in_clk_buf: IBUFDS generic map ( IOSTANDARD => "TMDS_33")
 port map ( I  => hdmi_rx_clk_p, IB => hdmi_rx_clk_n, O => tmds_in_clk);

in_rx0_buf: IBUFDS generic map ( IOSTANDARD => "TMDS_33")
 port map ( I  => hdmi_rx_p(0),  IB => hdmi_rx_n(0),  O  => tmds_in_ch0);

in_rx1_buf: IBUFDS generic map ( IOSTANDARD => "TMDS_33")
 port map ( I  => hdmi_rx_p(1),  IB => hdmi_rx_n(1),  O  => tmds_in_ch1);

in_rx2_buf: IBUFDS generic map ( IOSTANDARD => "TMDS_33")
 port map ( I  => hdmi_rx_p(2),  IB => hdmi_rx_n(2),  O  => tmds_in_ch2);

i_hdmi_input : entity work.hdmi_input port map (
        system_clk      => clk100,
        -- Pixel and serializer clocks
        pixel_clk       => pixel_clk_i,
        pixel_io_clk_x1 => pixel_io_clk_x1,
        pixel_io_clk_x5 => pixel_io_clk_x5,
        --- HDMI input signals
        hdmi_in_clk   => tmds_in_clk,
        hdmi_in_ch0   => tmds_in_ch0,
        hdmi_in_ch1   => tmds_in_ch1,
        hdmi_in_ch2   => tmds_in_ch2,
        -- are the HDMI symbols in sync?
        symbol_sync   => data_synced,
        pll_locked    => clock_locked,
        -- VGA internal Signals
        hdmi_detected => in_hdmi_detected,
        raw_blank     => raw_blank,
        raw_hsync     => raw_hsync,
        raw_vsync     => raw_vsync,
        raw_ch2       => raw_ch2,
        raw_ch1       => raw_ch1,
        raw_ch0       => raw_ch0,
        -- ADP data
        adp_data_valid      => adp_data_valid,
        adp_header_bit      => adp_header_bit,
        adp_frame_bit       => adp_frame_bit,
        adp_subpacket0_bits => adp_subpacket0_bits,
        adp_subpacket1_bits => adp_subpacket1_bits,
        adp_subpacket2_bits => adp_subpacket2_bits,
        adp_subpacket3_bits => adp_subpacket3_bits
    );

    -------------------------------------
    -- If the input data is in 422 format
    -- then convert it to 12-bit 444 data
    -------------------------------------
i_expand_422_to_444: entity work.expand_422_to_444 Port map (
        clk          => pixel_clk_i,
        ------------------
        -- Incoming raw data
        ------------------
        in_blank  => raw_blank,
        in_hsync  => raw_hsync,
        in_vsync  => raw_vsync,
        in_ch2    => raw_ch2,
        in_ch1    => raw_ch1,
        in_ch0    => raw_ch0,

        -------------------
        -- Processed pixels
        -------------------
        out_blank => fourfourfour_blank,
        out_hsync => fourfourfour_hsync,
        out_vsync => fourfourfour_vsync,
        out_U     => fourfourfour_U,
        out_V     => fourfourfour_V,
        out_W     => fourfourfour_W
    );

i_detect_interlace: entity work.detect_interlace Port map (
    clk             => pixel_clk_i,
    hsync           => raw_hsync,
    vsync           => raw_vsync,
    is_interlaced   => is_interlaced_i,
    is_second_field => is_second_field_i);

i_conversion_to_RGB: entity work.conversion_to_RGB
    port map (
           clk              => pixel_clk_i,
           ------------------------
           input_is_YCbCr   => input_is_YCbCr,
           input_is_sRGB    => input_is_sRGB,
           in_blank         => fourfourfour_blank,
           in_hsync         => fourfourfour_hsync,
           in_vsync         => fourfourfour_vsync,
           in_U             => fourfourfour_U,
           in_V             => fourfourfour_V,
           in_W             => fourfourfour_W,
           ------------------------
           out_blank        => rgb_blank,
           out_hsync        => rgb_hsync,
           out_vsync        => rgb_vsync,
           out_R            => rgb_R,
           out_G            => rgb_G,
           out_B            => rgb_B
    );

    -----------------------------------------
    -- Colour space conversion yet to be done
    -----------------------------------------
    in_blank <= rgb_blank;
    in_hsync <= rgb_hsync;
    in_vsync <= rgb_vsync;
    in_blue  <= rgb_B(11 downto 4);
    in_green <= rgb_G(11 downto 4);
    in_red   <= rgb_R(11 downto 4);

    ------------------------------------------------
    -- Processing the non-video data #1
    -- Extracting the Video Infopacket data we need
    -- to correctly convert the video data
    ------------------------------------------------
i_extract_video_infopacket_data: entity work.extract_video_infopacket_data port map (
    clk                 => pixel_clk_i,
    -- ADP data
    adp_data_valid      => adp_data_valid,
    adp_header_bit      => adp_header_bit,
    adp_frame_bit       => adp_frame_bit,
    adp_subpacket0_bits => adp_subpacket0_bits,
    adp_subpacket1_bits => adp_subpacket1_bits,
    adp_subpacket2_bits => adp_subpacket2_bits,
    adp_subpacket3_bits => adp_subpacket3_bits,
    -- The stuff we need
    input_is_YCbCr      => input_is_YCbCr,
    input_is_422        => input_is_422,
    input_is_sRGB       => input_is_sRGB
);

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
        tmds_out_clk  => tmds_out_clk,
        tmds_out_ch0  => tmds_out_ch0,
        tmds_out_ch1  => tmds_out_ch1,
        tmds_out_ch2  => tmds_out_ch2
    );

    -----------------------------
    -- Other HDMI control signals
    -----------------------------
    hdmi_tx_rsda  <= 'Z';
    hdmi_tx_cec   <= 'Z';
    hdmi_tx_rscl  <= '1';

    -----------------
    -- Output buffers
    -----------------
out_clk_buf: OBUFDS generic map ( IOSTANDARD => "TMDS_33",  SLEW => "FAST")
    port map ( O  => hdmi_tx_clk_p, OB => hdmi_tx_clk_n, I => tmds_out_clk);

out_tx0_buf: OBUFDS generic map ( IOSTANDARD => "TMDS_33",  SLEW => "FAST")
    port map ( O  => hdmi_tx_p(0), OB => hdmi_tx_n(0), I  => tmds_out_ch0);

out_tx1_buf: OBUFDS generic map ( IOSTANDARD => "TMDS_33",  SLEW => "FAST")
    port map ( O  => hdmi_tx_p(1), OB => hdmi_tx_n(1), I  => tmds_out_ch1);

out_tx2_buf: OBUFDS generic map ( IOSTANDARD => "TMDS_33",  SLEW => "FAST")
    port map ( O  => hdmi_tx_p(2), OB => hdmi_tx_n(2), I  => tmds_out_ch2);

end Behavioral;
