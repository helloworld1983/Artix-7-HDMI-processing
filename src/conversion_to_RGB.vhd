----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
--
-- Module Name: conversion_YCbCr_to_RGB - Behavioral
--
-- Description: Convert from RGB, studio level RGB or YCbCr to full range RGB
--
--              Designed to take the same amount of time regardless of conversion
--              being performed.
----------------------------------------------------------------------------------
-- When using 12-bit studio range inputs and the HD colourspace
--
-- R = (Y-64)*1.164 + (Cb-2048) *0.090 + (Cr-2048)*1.793
-- G = (Y-64)*1.164 - (Cb-2048) *0.213 - (Cr-2048)*0.533
-- B = (Y-64)*1.164 + (Cb-2048) *2.112 + (Cr-2048)*0.000
--
-- To avoid the problems with signed/unsigned multiplication this
-- has been rearranged to
--
-- R = Y*1.164 + Cb*0.090 + Cr*1.793 - 64*1.164 - 2048*0.090 - 2048*1.793
-- G = Y*1.164 - Cb*0.213 - Cr*0.533 - 64*1.164 + 2048*0.213 + 2048*0.533
-- B = Y*1.164 + Cb*2.112 + Cr*0.000 - 64*1.164 - 2048*2.112 - 2048*0.000
--
-- And then all the decimals have been scaled by 4096 This then only requires
-- five multipliers (as two are zero and three others are identical.
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

entity conversion_to_RGB is
    port ( clk      : in std_Logic;
           ------------------------
           in_blank : in std_logic;
           in_hsync : in std_logic;
           in_vsync : in std_logic;
           in_U     : in std_logic_vector(11 downto 0);  -- B or Cb
           in_V     : in std_logic_vector(11 downto 0);  -- G or Y
           in_W     : in std_logic_vector(11 downto 0);  -- R or Cr

           ------------------------
           out_blank : out std_logic;
           out_hsync : out std_logic;
           out_vsync : out std_logic;
           out_R     : out std_logic_vector(11 downto 0);
           out_G     : out std_logic_vector(11 downto 0);
           out_B     : out std_logic_vector(11 downto 0));
end entity;

architecture Behavioral of conversion_to_RGB is
    ------------------------------
    -- For the pipeline
    ------------------------------
    signal s1_blank : std_logic;
    signal s1_hsync : std_logic;
    signal s1_vsync : std_logic;
    signal s1_U     : std_logic_vector(12 downto 0);  -- B or Cb, plus underflow guard bit
    signal s1_V     : std_logic_vector(12 downto 0);  -- G or Y, plus underflow guard bit
    signal s1_W     : std_logic_vector(12 downto 0);  -- R or Cr, plus underflow guard bit

    signal s2_blank : std_logic;
    signal s2_hsync : std_logic;
    signal s2_vsync : std_logic;
    signal s2_U     : std_logic_vector(12 downto 0);  -- B or Cb, plus overflow guard bit
    signal s2_V     : std_logic_vector(12 downto 0);  -- G or Y, plus overflow guard bit
    signal s2_W     : std_logic_vector(12 downto 0);  -- R or Cr, plus overflow guard bit

begin
clk_proc: process(clk)
   begin
      if rising_edge(clk) then
         -----------------------------------------------
         -- Step 3: clamp the result
         -----------------------------------------------
         out_blank <= s2_blank;
         out_hsync <= s2_hsync;
         out_vsync <= s2_vsync;

            -- trap overflows form prior stage
            if s2_U(s2_U'high) = '0' then
                out_B     <= s2_U(s2_U'high-1 downto 0);
            else
                out_B     <= (others => '1');
            end if;

            if s2_V(s2_V'high) = '0' then
                out_G     <= s2_V(s2_V'high-1 downto 0);
            else
                out_G     <= (others => '1');
            end if;

            if s2_W(s2_W'high) = '0' then
                out_R     <= s2_W(s2_W'high-1 downto 0);
            else
                out_R     <= (others => '1');
            end if;
         end if;

         -------------------------------------------------
         -- Step 2: Add the partial results and remove the
         -- offset introduced by the use of studio range
         -------------------------------------------------
         s2_blank <= s1_blank;
         s2_hsync <= s1_hsync;
         s2_vsync <= s1_vsync;
         s2_U <= s1_U;
         s2_V <= s1_V;
         s2_W <= s1_W;

         -------------------------------------------------
         -- Step 1: Multiply the incoming values by the
         -- Conversion coefficients
         -------------------------------------------------
         s1_blank <= in_blank;
         s1_hsync <= in_hsync;
         s1_vsync <= in_vsync;
         s1_U     <= '0' & in_U;
         s1_V     <= '0' & in_V;
         s1_W     <= '0' & in_W;

   end process;
end architecture;
