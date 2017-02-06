----------------------------------------------------------------------------------
-- Engineer:    Mike Field <hamster@snap.net.nz>
--
-- Create Date: 22.07.2015 21:10:34
-- Module Name: hdmi_design - Behavioral
-- Project Name:
--
-- Description: Top level of a video processing design
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

entity hdmi_design is
    Port (
        clk100    : in STD_LOGIC;

        --HDMI input signals
        hdmi_rx_cec   : inout std_logic;
        hdmi_rx_hpa   : out   std_logic;
        hdmi_rx_scl   : in    std_logic;
        hdmi_rx_sda   : inout std_logic;
        hdmi_rx_txen  : out   std_logic;
        hdmi_rx_clk_n : in    std_logic;
        hdmi_rx_clk_p : in    std_logic;
        hdmi_rx_n     : in    std_logic_vector(2 downto 0);
        hdmi_rx_p     : in    std_logic_vector(2 downto 0);

        --- HDMI out
        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk_n : out   std_logic;
        hdmi_tx_clk_p : out   std_logic;
        hdmi_tx_hpd   : in    std_logic;
        hdmi_tx_rscl  : inout std_logic;
        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx_p     : out   std_logic_vector(2 downto 0);
        hdmi_tx_n     : out   std_logic_vector(2 downto 0)
    );
end hdmi_design;

architecture Behavioral of hdmi_design is

    signal blank  : std_logic;
    signal hsync  : std_logic;
    signal vsync  : std_logic;
    signal red    : std_logic_vector(7 downto 0);
    signal green  : std_logic_vector(7 downto 0);
    signal blue   : std_logic_vector(7 downto 0);

begin

i_hdmi_io: entity work.hdmi_io port map (
        clk100        => clk100,
        ---------------------
        -- HDMI input signals
        ---------------------
        hdmi_rx_cec   => hdmi_rx_cec,
        hdmi_rx_hpa   => hdmi_rx_hpa,
        hdmi_rx_scl   => hdmi_rx_scl,
        hdmi_rx_sda   => hdmi_rx_sda,
        hdmi_rx_txen  => hdmi_rx_txen,
        hdmi_rx_clk_n => hdmi_rx_clk_n,
        hdmi_rx_clk_p => hdmi_rx_clk_p,
        hdmi_rx_p     => hdmi_rx_p,
        hdmi_rx_n     => hdmi_rx_n,

        ----------------------
        -- HDMI output signals
        ----------------------
        hdmi_tx_cec   => hdmi_tx_cec,
        hdmi_tx_clk_n => hdmi_tx_clk_n,
        hdmi_tx_clk_p => hdmi_tx_clk_p,
        hdmi_tx_hpd   => hdmi_tx_hpd,
        hdmi_tx_rscl  => hdmi_tx_rscl,
        hdmi_tx_rsda  => hdmi_tx_rsda,
        hdmi_tx_p     => hdmi_tx_p,
        hdmi_tx_n     => hdmi_tx_n,


        pixel_clk => open,
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_blank        => blank,
        in_hsync        => hsync,
        in_vsync        => vsync,
        in_red          => red,
        in_green        => green,
        in_blue         => blue,

        -----------------------------------
        -- VGA data to be converted to HDMI
        -----------------------------------
        out_blank => blank,
        out_hsync => hsync,
        out_vsync => vsync,
        out_red   => red,
        out_green => green,
        out_blue  => blue
    );

end Behavioral;