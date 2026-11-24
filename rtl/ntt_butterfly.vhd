-- Cooley-Tukey butterfly, 3 register stages, bit-exact with pq-crystals ref:
--   t = montgomery_reduce(b*zeta); sum = a+t; diff = a-t   (int16 wrap)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity ntt_butterfly is port(
  clk : in std_logic; a, b, zeta : in signed(15 downto 0); sum, diff : out signed(15 downto 0)); end;
architecture rtl of ntt_butterfly is
  constant QINV : signed(15 downto 0) := to_signed(-3327, 16);   -- q^-1 mod 2^16
  constant Q    : signed(15 downto 0) := to_signed(3329, 16);
  signal p, mprod, mq, r : signed(31 downto 0) := (others => '0');
  signal m, a1, a2, t : signed(15 downto 0) := (others => '0');
begin
  mprod <= p(15 downto 0) * QINV;
  m     <= mprod(15 downto 0);
  mq    <= m * Q;
  r     <= shift_right(p - mq, 16);              -- Montgomery reduce
  process(clk) begin
    if rising_edge(clk) then
      p <= b * zeta;  a1 <= a;                   -- E0: multiply
      t <= r(15 downto 0);  a2 <= a1;            -- E1: Montgomery
      sum <= a2 + t;  diff <= a2 - t;            -- E2: add/sub
    end if;
  end process;
end;
