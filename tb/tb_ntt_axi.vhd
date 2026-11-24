library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity tb_ntt_axi is end;
architecture sim of tb_ntt_axi is
  signal clk : std_logic := '0'; signal rn : std_logic := '0';
  signal aw, ar : std_logic_vector(11 downto 0) := (others => '0');
  signal awv, wv, arv, awr, wr, arr, bv, rv : std_logic := '0';
  signal wd, rd : std_logic_vector(31 downto 0) := (others => '0');
  signal bresp, rresp : std_logic_vector(1 downto 0);
begin
  clk <= not clk after 5 ns;
  d : entity work.ntt_axi port map(clk, rn, aw, awv, awr, wd, "1111", wv, wr, bresp, bv, '1',
                                   ar, arv, arr, rd, rresp, rv, '1');
  process
    variable s : std_logic_vector(31 downto 0); variable errs : natural := 0;
    procedure wreg(a : integer; x : integer) is begin
      aw <= std_logic_vector(to_unsigned(a, 12)); wd <= std_logic_vector(to_signed(x, 32)); awv <= '1'; wv <= '1';
      wait until rising_edge(clk) and awr = '1'; wait for 1 ns; awv <= '0'; wv <= '0'; end;
    procedure rreg(a : integer; x : out std_logic_vector(31 downto 0)) is begin
      ar <= std_logic_vector(to_unsigned(a, 12)); arv <= '1';
      wait until rising_edge(clk) and arr = '1'; wait for 1 ns; arv <= '0';
      wait until rising_edge(clk) and rv = '1'; x := rd; wait for 1 ns; end;
    type iarr is array (0 to 255) of integer; variable x : iarr;
  begin
    wait for 40 ns; wait until rising_edge(clk); rn <= '1'; wait until rising_edge(clk);
    for i in 0 to 255 loop x(i) := (i * 37 + 11) mod 3329; wreg(16#400# + 4*i, x(i)); end loop;
    wreg(0, 1); s := x"00000001"; while s(0) = '1' or s(1) = '0' loop rreg(4, s); end loop;
    rreg(16#400#, s); report "coef0=" & integer'image(to_integer(signed(s))) severity note;
    for i in 0 to 255 loop rreg(16#400# + 4*i, s);
      if s(31 downto 16) /= (15 downto 0 => s(15)) then errs := errs + 1; end if; end loop;
    if errs = 0 then report "AXI PASS (handshake/status/sign-ext)" severity note; else report "AXI FAIL" severity failure; end if;
    std.env.finish;
  end process;
end;
