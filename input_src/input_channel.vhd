----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Create Date: 30.07.2015 23:11:34
-- Module Name: input_channel - Behavioral
--
-- Description: Receiving one of the three HDMI input channels. and decoding
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

entity input_channel is
    Port ( clk_mgmt        : in STD_LOGIC;
           clk             : in  STD_LOGIC;
           clk_x1          : in  STD_LOGIC;
           clk_x5          : in  STD_LOGIC;
           serial          : in  STD_LOGIC;
           reset           : in  std_logic;
           ctl_valid       : out std_logic;
           ctl             : out std_logic_vector (1 downto 0);
           data_valid      : out std_logic;
           data            : out std_logic_vector (7 downto 0));
end input_channel;

architecture Behavioral of input_channel is

    signal delay_count     : std_logic_vector (4 downto 0);
    signal delay_ce        : std_logic;
    signal bitslip         : std_logic;
    signal symbol          : std_logic_vector (9 downto 0);
    signal invalid_symbol  : std_logic;

begin

i_deser: entity work.deserialiser_1_to_10 port map (
        clk_mgmt    => clk_mgmt,
        delay_ce    => delay_ce,
        delay_count => delay_count,
        clk         => clk,
        clk_x1      => clk_x1,
        bitslip     => bitslip,
        clk_x5      => clk_x5,
        reset       => reset,
        serial      => serial,
        data        => symbol);

i_decoder: entity work.tmds_decoder port map (
        clk             => clk,
        symbol          => symbol,
        invalid_symbol  => invalid_symbol,
        ctl_valid       => ctl_valid,
        ctl             => ctl,
        data_valid      => data_valid,
        data            => data
    );

i_alignment_detect: entity work.alignment_detect port map (
           clk            => clk,
           invalid_symbol => invalid_symbol,
           delay_count    => delay_count,
           delay_ce       => delay_ce,
           bitslip        => bitslip);

end Behavioral;
