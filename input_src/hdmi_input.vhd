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

        pixel_clk       : out std_logic;  -- Driven by BUFG
        pixel_io_clk_x1 : out std_logic;  -- Driven by BUFFIO
        pixel_io_clk_x5 : out std_logic;  -- Driven by BUFFIO

        -- HDMI input signals
        hdmi_in_clk   : in    std_logic;
        hdmi_in_ch0   : in    std_logic;
        hdmi_in_ch1   : in    std_logic;
        hdmi_in_ch2   : in    std_logic;

        -- Status
        pll_locked   : out std_logic;
        symbol_sync  : out std_logic;

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

    signal clk_pixel_raw     : std_logic;

    signal clk_pixel         : std_logic;
    signal clk_pixel_x1      : std_logic;
    signal clk_pixel_x5      : std_logic;
    signal clk_pixel_x1_raw  : std_logic;
    signal clk_pixel_x5_raw  : std_logic;
    signal clkfb_2           : std_logic;
    signal locked            : std_logic;
    signal reset             : std_logic;
    signal ser_reset         : std_logic;
    signal ser_ce            : std_logic;
    -------------------------------------------------------------
    -- The raw 10-bit received symbols
    -------------------------------------------------------------
    signal ch0_symbol  : std_logic_vector(9 downto 0);
    signal ch1_symbol  : std_logic_vector(9 downto 0);
    signal ch2_symbol  : std_logic_vector(9 downto 0);

    -------------------------------------------------------------
    -- For the decoded TMDS data
    -------------------------------------------------------------
    signal ch0_invalid_symbol  : std_logic;
    signal ch0_ctl_valid       : std_logic;
    signal ch0_ctl             : std_logic_vector(1 downto 0);
    signal ch0_terc4_valid     : std_logic;
    signal ch0_terc4           : std_logic_vector (3 downto 0);
    signal ch0_data_valid      : std_logic;
    signal ch0_data            : std_logic_vector(7 downto 0);
    signal ch0_guardband_valid : std_logic;
    signal ch0_guardband       : std_logic_vector (0 downto 0);
    signal ch0_delay_count     : std_logic_vector (4 downto 0);
    signal ch0_delay_ce        : STD_LOGIC;
    signal ch0_bitslip         : STD_LOGIC;
    signal ch0_symbol_sync     : STD_LOGIC;

    signal ch1_invalid_symbol  : std_logic;
    signal ch1_ctl_valid       : std_logic;
    signal ch1_ctl             : std_logic_vector(1 downto 0);
    signal ch1_terc4_valid     : std_logic;
    signal ch1_terc4           : std_logic_vector (3 downto 0);
    signal ch1_data_valid      : std_logic;
    signal ch1_data            : std_logic_vector(7 downto 0);
    signal ch1_guardband_valid : std_logic;
    signal ch1_guardband       : std_logic_vector (0 downto 0);
    signal ch1_delay_count     : std_logic_vector (4 downto 0);
    signal ch1_delay_ce        : STD_LOGIC;
    signal ch1_bitslip         : STD_LOGIC;
    signal ch1_symbol_sync     : STD_LOGIC;

    signal ch2_invalid_symbol  : std_logic;
    signal ch2_ctl_valid       : std_logic;
    signal ch2_ctl             : std_logic_vector(1 downto 0);
    signal ch2_terc4_valid     : std_logic;
    signal ch2_terc4           : std_logic_vector (3 downto 0);
    signal ch2_data_valid      : std_logic;
    signal ch2_data            : std_logic_vector(7 downto 0);
    signal ch2_guardband_valid : std_logic;
    signal ch2_guardband       : std_logic_vector (0 downto 0);
    signal ch2_delay_count     : std_logic_vector (4 downto 0);
    signal ch2_delay_ce        : STD_LOGIC;
    signal ch2_bitslip         : STD_LOGIC;
    signal ch2_symbol_sync     : STD_LOGIC;

    signal reset_counter  : unsigned(7 downto 0) := (others => '1');

    signal last_was_ctl         : std_logic := '0';

    signal in_dvid              : std_logic := '0';
begin
    pll_locked  <= locked;
    reset       <= std_logic(reset_counter(reset_counter'high));

   --------------------------------
   -- MMCM driven by the HDMI clock
   --------------------------------
hdmi_MMCME2_BASE_inst : MMCME2_BASE
   generic map (
      BANDWIDTH => "OPTIMIZED",      -- Jitter programming (OPTIMIZED, HIGH, LOW)
      DIVCLK_DIVIDE   => 1,          -- Master division value (1-106)
      CLKFBOUT_MULT_F => 5.0,        -- Multiply value for all CLKOUT (2.000-64.000).
      CLKFBOUT_PHASE => 0.0,         -- Phase offset in degrees of CLKFB (-360.000-360.000).
      CLKIN1_PERIOD => 12.5, --1000.0/148.5, -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
      CLKOUT0_DIVIDE_F => 5.0,       -- Divide amount for CLKOUT0 (1.000-128.000).
      CLKOUT1_DIVIDE   => 5,
      CLKOUT2_DIVIDE   => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      CLKOUT0_PHASE => 0.0,
      CLKOUT1_PHASE => 0.0,
      CLKOUT2_PHASE => 0.0,
      REF_JITTER1 => 0.0,        -- Reference input jitter in UI (0.000-0.999).
      STARTUP_WAIT => FALSE      -- Delays DONE until MMCM is locked (FALSE, TRUE)
   )
   port map (
      -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
      CLKOUT0   => clk_pixel_raw,    -- 1-bit output: CLKOUT0
      CLKOUT1   => clk_pixel_x1_raw, -- 1-bit output: CLKOUT1
      CLKOUT2   => clk_pixel_x5_raw, -- 1-bit output: CLKOUT2
      -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
      CLKFBOUT  => clkfb_2,       -- 1-bit output: Feedback clock
      CLKFBOUTB => open,          -- 1-bit output: Inverted CLKFBOUT
      -- Status Ports: 1-bit (each) output: MMCM status ports
      LOCKED    => locked,        -- 1-bit output: LOCK
      -- Clock Inputs: 1-bit (each) input: Clock input
      CLKIN1    => hdmi_in_clk, -- 1-bit input: Clock
      -- Control Ports: 1-bit (each) input: MMCM control ports
      PWRDWN    => '0',           -- 1-bit input: Power-down
      RST       => '0',           -- 1-bit input: Reset
      -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
      CLKFBIN   => clkfb_2        -- 1-bit input: Feedback clock
   );

   ----------------------------------
   -- Force the highest speed clock
   -- through the IO clock buffer
   -- (this is only rated for 600MHz!)
   -----------------------------------
BUFIO_x5_inst : BUFIO
   port map (
      I => clk_pixel_x5_raw, -- 1-bit input: Clock input (connect to an IBUF or BUFMR).
      O => clk_pixel_x5      -- 1-bit output: Clock output (connect to I/O clock loads).
   );

BUFIO_x1_inst : BUFG
      port map (
         I => clk_pixel_x1_raw, -- 1-bit input: Clock input (connect to an IBUF or BUFMR).
         O => clk_pixel_x1      -- 1-bit output: Clock output (connect to I/O clock loads).
      );

BUFIO_inst : BUFG
      port map (
         I => clk_pixel_raw, -- 1-bit input: Clock input (connect to an IBUF or BUFMR).
         O => clk_pixel      -- 1-bit output: Clock output (connect to I/O clock loads).
      );
      pixel_clk       <= clk_pixel;
      pixel_io_clk_x1 <= clk_pixel_x1;
      pixel_io_clk_x5 <= clk_pixel_x5;

ch0: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch0,
        invalid_symbol  => ch0_invalid_symbol,
        symbol          => ch0_symbol,
        ctl_valid       => ch0_ctl_valid,
        ctl             => ch0_ctl,
        terc4_valid     => ch0_terc4_valid,
        terc4           => ch0_terc4,
        guardband_valid => ch0_guardband_valid,
        guardband       => ch0_guardband,
        data_valid      => ch0_data_valid,
        data            => ch0_data,
        reset           => ser_reset,
        symbol_sync     => ch0_symbol_sync
    );

ch1: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch1,
        symbol          => ch1_symbol,
        invalid_symbol  => ch1_invalid_symbol,
        ctl_valid       => ch1_ctl_valid,
        ctl             => ch1_ctl,
        terc4_valid     => ch1_terc4_valid,
        terc4           => ch1_terc4,
        guardband_valid => ch1_guardband_valid,
        guardband       => ch1_guardband,
        data_valid      => ch1_data_valid,
        data            => ch1_data,
        reset           => ser_reset,
        symbol_sync     => ch1_symbol_sync
    );

ch2: entity work.input_channel
    port map (
        clk_mgmt        => clk100,
        clk             => clk_pixel,
        ce              => ser_ce,
        clk_x1          => clk_pixel_x1,
        clk_x5          => clk_pixel_x5,
        serial          => hdmi_in_ch2,
        invalid_symbol  => ch2_invalid_symbol,
        symbol          => ch2_symbol,
        ctl_valid       => ch2_ctl_valid,
        ctl             => ch2_ctl,
        terc4_valid     => ch2_terc4_valid,
        terc4           => ch2_terc4,
        guardband_valid => ch2_guardband_valid,
        guardband       => ch2_guardband,
        data_valid      => ch2_data_valid,
        data            => ch2_data,
        reset           => ser_reset,
        symbol_sync     => ch2_symbol_sync
    );

    symbol_sync <= ch0_symbol_sync and ch1_symbol_sync and ch2_symbol_sync;

hdmi_section_decode: process(clk_pixel)
    begin
        if rising_edge(clk_pixel) then
            -------------------------------------------------------------------
            -- Output the values depending on what sort of data block we are in
            -------------------------------------------------------------------
            if ch0_ctl_valid = '1' and ch1_ctl_valid = '1' and ch2_ctl_valid = '1' then
                -------------------------------------------------------------------
                -- As soon as we see avalid CTL symbols we are no longer in the
                -- video or aux data period it doesn't have any trailing guard band
                -------------------------------------------------------------------
                in_dvid   <= '0';
                raw_vsync <= ch0_ctl(1);
                raw_hsync <= ch0_ctl(0);
                raw_blank <= '1';
                raw_ch2   <= (others => '0');
                raw_ch1   <= (others => '0');
                raw_ch0   <= (others => '0');
                last_was_ctl   <= '1';
            else
                last_was_ctl <= '0';
                if in_dvid = '1' then
                    -- In the Video data period
                    raw_vsync <= '0';
                    raw_hsync <= '0';
                    raw_blank <= '0';
                    raw_ch2   <= ch2_data;
                    raw_ch1   <= ch1_data;
                    raw_ch0   <= ch0_data;
                end if;
            end if;
            --------------------------------
            -- Is this some DVID video data?
            --------------------------------
            if last_was_ctl = '1' and ch0_data_valid = '1' and ch1_data_valid = '1' and ch2_data_valid = '1' then
                in_dvid <= '1';
            end if;

        end if;
    end process;

------------------------------------------
-- Reset the receivers if PLL lock is lost
------------------------------------------
reset_proc: process(clk100)
    begin
        if rising_edge(clk100) then
            if locked = '1' then
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
end Behavioral;
