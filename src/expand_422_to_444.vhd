----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: expand_422_to_444 - Behavioral
--
-- Description: Convert incoming 422 data to 444
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

entity expand_422_to_444 is
    Port ( clk : in STD_LOGIC;
        ------------------
        -- Incoming pixels
        ------------------
        in_blank  : in std_logic;
        in_hsync  : in std_logic;
        in_vsync  : in std_logic;
        in_ch2    : in std_logic_vector(7 downto 0);
        in_ch1    : in std_logic_vector(7 downto 0);
        in_ch0    : in std_logic_vector(7 downto 0);

        -------------------
        -- Processed pixels
        -------------------
        out_blank : out std_logic;
        out_hsync : out std_logic;
        out_vsync : out std_logic;
        out_U     : out std_logic_vector(11 downto 0);  -- B or Cb
        out_V     : out std_logic_vector(11 downto 0);  -- G or Y
        out_W     : out std_logic_vector(11 downto 0)   -- R or Cr
    );
end expand_422_to_444;

architecture Behavioral of expand_422_to_444 is

begin

process(clk)
    begin
        if rising_edge(clk) then
            ------------------------------------------------------
            -- RGB
            ------------------------------------------------------
            out_blank <= in_blank;
            out_hsync <= in_hsync;
            out_vsync <= in_vsync;
            out_U     <= in_ch0 & "0000";  -- B
            out_V     <= in_ch1 & "0000";  -- G
            out_W     <= in_ch2 & "0000";  -- R
        end if;
    end process;
end Behavioral;
