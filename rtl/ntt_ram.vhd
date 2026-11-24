-- 128x16 simple dual-port RAM (infers BRAM), sync read
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity ntt_ram is port(
  clk, we : in std_logic; waddr : in std_logic_vector(6 downto 0); wdata : in std_logic_vector(15 downto 0);
  raddr : in std_logic_vector(6 downto 0); rdata : out std_logic_vector(15 downto 0)); end;
architecture rtl of ntt_ram is
  type mem_t is array (0 to 127) of std_logic_vector(15 downto 0);
  signal m : mem_t := (others => (others => '0'));
  attribute ram_style : string; attribute ram_style of m : signal is "block";
begin
  process(clk) begin
    if rising_edge(clk) then
      if we = '1' then m(to_integer(unsigned(waddr))) <= wdata; end if;
      rdata <= m(to_integer(unsigned(raddr)));
    end if;
  end process;
end;
