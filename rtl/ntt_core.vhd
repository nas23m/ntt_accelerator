-- 256-point ML-KEM forward NTT core (q=3329), one butterfly/cycle, 2 BRAM banks.
-- bank = parity(addr), idx = addr(7:1); j and j+len (len>=2) always hit different banks.
-- Host read data is Barrett-reduced (== ref ntt() followed by poly_reduce()).
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity ntt_core is port(
  clk, rst_n, start : in std_logic; busy, done : out std_logic;
  h_we : in std_logic; h_addr : in std_logic_vector(7 downto 0);
  h_wdata : in std_logic_vector(15 downto 0); h_rdata : out std_logic_vector(15 downto 0)); end;
architecture rtl of ntt_core is
  type st_t is (IDLE, RUN, WAIT_S);
  signal st : st_t := IDLE;
  signal layer, w : unsigned(2 downto 0) := (others => '0');
  signal n : unsigned(6 downto 0) := (others => '0');
  signal busy_i, done_i : std_logic := '0';
  signal ia, ib : unsigned(7 downto 0) := (others => '0');
  signal zk : unsigned(6 downto 0) := (others => '0');
  signal v0, pa0 : std_logic;
  signal v, p : std_logic_vector(1 to 4) := (others => '0');
  type addr_arr is array (1 to 4) of unsigned(7 downto 0);
  signal iaa, ibb : addr_arr := (others => (others => '0'));
  signal q0, q1, zq, wd0, wd1 : std_logic_vector(15 downto 0);
  signal ra0, ra1, wa0, wa1 : std_logic_vector(6 downto 0);
  signal we0, we1, hp, par_h : std_logic := '0';
  signal sum, diff, a, b : signed(15 downto 0);

  function parity(x : unsigned) return std_logic is
    variable r : std_logic := '0';
  begin
    for i in x'range loop r := r xor x(i); end loop; return r;
  end;

  function barrett(x : signed(15 downto 0)) return signed is
    variable pr : signed(31 downto 0); variable t : signed(31 downto 0); variable tq : signed(31 downto 0);
  begin
    pr := x * to_signed(20159, 16) + to_signed(2**25, 32);
    t  := shift_right(pr, 26);
    tq := t(15 downto 0) * to_signed(3329, 16);
    return x - tq(15 downto 0);
  end;
begin
  busy <= busy_i; done <= done_i;
  v0 <= '1' when st = RUN else '0';
  par_h <= parity(unsigned(h_addr));

  -- stage 0 address generation
  process(layer, n)
    variable lgl : natural; variable len8, blk, off, i8 : unsigned(7 downto 0);
  begin
    lgl  := 7 - to_integer(layer);
    len8 := shift_right(to_unsigned(128, 8), to_integer(layer));
    blk  := shift_right(resize(n, 8), lgl);
    off  := resize(n, 8) and (len8 - 1);
    i8   := shift_left(blk, lgl + 1) or off;
    ia <= i8; ib <= i8 + len8; pa0 <= parity(i8);
    zk <= shift_left(to_unsigned(1, 7), to_integer(layer)) + resize(shift_right(n, lgl), 7);
  end process;

  -- sideband pipeline
  process(clk) begin
    if rising_edge(clk) then
      v(1) <= v0; p(1) <= pa0; iaa(1) <= ia; ibb(1) <= ib;
      for k in 2 to 4 loop
        v(k) <= v(k-1); p(k) <= p(k-1); iaa(k) <= iaa(k-1); ibb(k) <= ibb(k-1);
      end loop;
      if rst_n = '0' then v <= (others => '0'); end if;
    end if;
  end process;

  -- memory banks
  ra0 <= std_logic_vector(ib(7 downto 1)) when (busy_i = '1' and pa0 = '1') else
         std_logic_vector(ia(7 downto 1)) when busy_i = '1' else h_addr(7 downto 1);
  ra1 <= std_logic_vector(ia(7 downto 1)) when (busy_i = '1' and pa0 = '1') else
         std_logic_vector(ib(7 downto 1)) when busy_i = '1' else h_addr(7 downto 1);
  we0 <= v(4) when busy_i = '1' else (h_we and not par_h);
  we1 <= v(4) when busy_i = '1' else (h_we and par_h);
  wa0 <= std_logic_vector(ibb(4)(7 downto 1)) when (busy_i = '1' and p(4) = '1') else
         std_logic_vector(iaa(4)(7 downto 1)) when busy_i = '1' else h_addr(7 downto 1);
  wa1 <= std_logic_vector(iaa(4)(7 downto 1)) when (busy_i = '1' and p(4) = '1') else
         std_logic_vector(ibb(4)(7 downto 1)) when busy_i = '1' else h_addr(7 downto 1);
  wd0 <= std_logic_vector(diff) when (busy_i = '1' and p(4) = '1') else
         std_logic_vector(sum)  when busy_i = '1' else h_wdata;
  wd1 <= std_logic_vector(sum)  when (busy_i = '1' and p(4) = '1') else
         std_logic_vector(diff) when busy_i = '1' else h_wdata;
  b0 : entity work.ntt_ram port map(clk, we0, wa0, wd0, ra0, q0);
  b1 : entity work.ntt_ram port map(clk, we1, wa1, wd1, ra1, q1);
  zr : entity work.zeta_rom port map(clk, std_logic_vector(zk), zq);

  a <= signed(q1) when p(1) = '1' else signed(q0);
  b <= signed(q0) when p(1) = '1' else signed(q1);
  bf : entity work.ntt_butterfly port map(clk, a, b, signed(zq), sum, diff);

  -- host read path
  process(clk) begin if rising_edge(clk) then hp <= par_h; end if; end process;
  h_rdata <= std_logic_vector(barrett(signed(q1))) when hp = '1' else std_logic_vector(barrett(signed(q0)));

  -- control
  process(clk) begin
    if rising_edge(clk) then
      done_i <= '0';
      if rst_n = '0' then
        st <= IDLE; busy_i <= '0'; layer <= (others => '0'); n <= (others => '0'); w <= (others => '0');
      else
        case st is
          when IDLE =>
            if start = '1' then st <= RUN; layer <= (others => '0'); n <= (others => '0'); busy_i <= '1'; end if;
          when RUN =>
            if n = 127 then n <= (others => '0'); st <= WAIT_S; w <= (others => '0');
            else n <= n + 1; end if;
          when WAIT_S =>
            if w = 5 then
              if layer = 6 then st <= IDLE; busy_i <= '0'; done_i <= '1';
              else layer <= layer + 1; st <= RUN; end if;
            else w <= w + 1; end if;
        end case;
      end if;
    end if;
  end process;
end;
