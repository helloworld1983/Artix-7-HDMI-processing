----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: hdmi_input - Behavioral
--
-- Description: Decode the video data out of an incoming HDMI data stream.
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
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity hdmi_input is
    Port (
        clk100      : in  std_logic;
        clk200      : in  std_logic;

        clk_pixel    : in std_logic;
        clk_pixel_x1 : in std_logic;
        clk_pixel_x5 : in std_logic;
        clk_locked   : in std_logic;

        -- HDMI input signals
        hdmi_in_ch0   : in    std_logic;
        hdmi_in_ch1   : in    std_logic;
        hdmi_in_ch2   : in    std_logic;

        -- Raw data signals
        raw_blank : out std_logic;
        raw_hsync : out std_logic;
        raw_vsync : out std_logic;
        raw_ch0   : out std_logic_vector(7 downto 0);
        raw_ch1   : out std_logic_vector(7 downto 0);
        raw_ch2   : out std_logic_vector(7 downto 0)
    );
end hdmi_input;

architecture Behavioral of hdmi_input is

    signal ser_reset         : std_logic;
    signal ser_ce            : std_logic;

    -------------------------------------------------------------
    -- For the decoded TMDS data
    -------------------------------------------------------------
    signal ch0_ctl_valid       : std_logic;
    signal ch0_ctl             : std_logic_vector(1 downto 0);
    signal ch0_data_valid      : std_logic;
    signal ch0_data            : std_logic_vector(7 downto 0);

    signal ch1_ctl_valid       : std_logic;
    signal ch1_data_valid      : std_logic;
    signal ch1_data            : std_logic_vector(7 downto 0);

    signal ch2_ctl_valid       : std_logic;
    signal ch2_data_valid      : std_logic;
    signal ch2_data            : std_logic_vector(7 downto 0);

    signal reset_counter  : unsigned(7 downto 0) := (others => '1');

begin

------------------------------------------
-- Reset the receivers if PLL lock is lost
------------------------------------------
reset_proc: process(clk100)
    begin
        if rising_edge(clk100) then
            if clk_locked = '1' then
                if reset_counter > 0 then
                    reset_counter <= reset_counter-1;
                end if;
            else
                reset_counter <= (others => '1');
            end if;
        end if;
    end process;

reset_proc2: process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            ser_reset <= reset_counter(reset_counter'high);
            ser_ce    <= not ser_reset;
        end if;
    end process;


ch0: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch0,
        invalid_symbol  => open,
        symbol          => open,
        ctl_valid       => ch0_ctl_valid,
        ctl             => ch0_ctl,
        data_valid      => ch0_data_valid,
        data            => ch0_data,
        reset           => ser_reset,
        symbol_sync     => open
    );

ch1: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch1,
        symbol          => open,
        invalid_symbol  => open,
        ctl_valid       => ch1_ctl_valid,
        ctl             => open,
        data_valid      => ch1_data_valid,
        data            => ch1_data,
        reset           => ser_reset,
        symbol_sync     => open
    );

ch2: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch2,
        invalid_symbol  => open,
        symbol          => open,
        ctl_valid       => ch2_ctl_valid,
        ctl             => open,
        data_valid      => ch2_data_valid,
        data            => ch2_data,
        reset           => ser_reset,
        symbol_sync     => open
    );

hdmi_section_decode: process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            if ch0_ctl_valid = '1' and ch1_ctl_valid = '1' and ch2_ctl_valid = '1' then
                raw_vsync <= ch0_ctl(1);
                raw_hsync <= ch0_ctl(0);
                raw_blank <= '1';
                raw_ch2   <= (others => '0');
                raw_ch1   <= (others => '0');
                raw_ch0   <= (others => '0');
            elsif ch0_data_valid = '1' and ch1_data_valid = '1' and ch2_data_valid = '1' then
                raw_vsync <= '0';
                raw_hsync <= '0';
                raw_blank <= '0';
                raw_ch2   <= ch2_data;
                raw_ch1   <= ch1_data;
                raw_ch0   <= ch0_data;
            end if;
        end if;
    end process;

end Behavioral;
