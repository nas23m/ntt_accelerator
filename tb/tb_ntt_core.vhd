library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all; use std.textio.all;
entity tb_ntt_core is
  generic(VEC_DIR : string := "../../../../../ref");   -- relative to xsim run dir; ghdl: -gVEC_DIR=ref
end;
architecture sim of tb_ntt_core is
  constant NV : natural := 64;
  type mem_t is array (0 to NV*256-1) of std_logic_vector(15 downto 0);
  function hex(s : string) return std_logic_vector is
    variable r : std_logic_vector(15 downto 0); variable d : integer;
  begin
    for i in 0 to 3 loop
      case s(i+1) is
        when '0' to '9' => d := character'pos(s(i+1)) - 48;
        when others => d := character'pos(s(i+1)) - 87;
      end case;
      r(15-4*i downto 12-4*i) := std_logic_vector(to_unsigned(d, 4));
    end loop; return r;
  end;
  impure function load(fn : string) return mem_t is
    file f : text open read_mode is fn; variable l : line; variable s : string(1 to 4); variable m : mem_t;
  begin
    for i in m'range loop readline(f, l); read(l, s); m(i) := hex(s); end loop; return m;
  end;
  signal clk : std_logic := '0'; signal rst_n, start, h_we : std_logic := '0';
  signal busy, done : std_logic; signal h_addr : std_logic_vector(7 downto 0) := (others => '0');
  signal h_wdata, h_rdata : std_logic_vector(15 downto 0) := (others => '0');
begin
  clk <= not clk after 5 ns;
  dut : entity work.ntt_core port map(clk, rst_n, start, busy, done, h_we, h_addr, h_wdata, h_rdata);
  process
    variable vin  : mem_t := load(VEC_DIR & "/vec_in.mem");
    variable vexp : mem_t := load(VEC_DIR & "/vec_exp.mem");
    variable errs : natural := 0;
  begin
    wait for 40 ns; wait until rising_edge(clk); rst_n <= '1'; wait until rising_edge(clk);
    for v in 0 to NV-1 loop
      for i in 0 to 255 loop
        h_we <= '1'; h_addr <= std_logic_vector(to_unsigned(i, 8)); h_wdata <= vin(v*256+i);
        wait until rising_edge(clk); wait for 1 ns;
      end loop;
      h_we <= '0'; start <= '1'; wait until rising_edge(clk); wait for 1 ns; start <= '0';
      wait until rising_edge(clk) and done = '1'; wait until rising_edge(clk); wait for 1 ns;
      for i in 0 to 255 loop
        h_addr <= std_logic_vector(to_unsigned(i, 8)); wait until rising_edge(clk); wait for 1 ns;
        if h_rdata /= vexp(v*256+i) then
          errs := errs + 1;
          if errs < 10 then report "MISMATCH v=" & integer'image(v) & " i=" & integer'image(i) severity error; end if;
        end if;
      end loop;
    end loop;
    if errs = 0 then report "PASS: 64 vectors bit-exact vs pq-crystals reference" severity note;
    else report "FAIL: " & integer'image(errs) & " mismatches" severity failure; end if;
    std.env.finish;
  end process;
end;
