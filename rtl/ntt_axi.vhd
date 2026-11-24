-- AXI4-Lite wrapper. 0x000 CTRL (W bit0=start) | 0x004 STATUS (R bit0=busy, bit1=done)
-- 0x400 + 4*i : coefficient i (write: low 16 bits; read: sign-extended, Barrett-reduced)
library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;
entity ntt_axi is port(
  s_axi_aclk, s_axi_aresetn : in std_logic;
  s_axi_awaddr : in std_logic_vector(11 downto 0); s_axi_awvalid : in std_logic; s_axi_awready : out std_logic;
  s_axi_wdata : in std_logic_vector(31 downto 0); s_axi_wstrb : in std_logic_vector(3 downto 0);
  s_axi_wvalid : in std_logic; s_axi_wready : out std_logic;
  s_axi_bresp : out std_logic_vector(1 downto 0); s_axi_bvalid : out std_logic; s_axi_bready : in std_logic;
  s_axi_araddr : in std_logic_vector(11 downto 0); s_axi_arvalid : in std_logic; s_axi_arready : out std_logic;
  s_axi_rdata : out std_logic_vector(31 downto 0); s_axi_rresp : out std_logic_vector(1 downto 0);
  s_axi_rvalid : out std_logic; s_axi_rready : in std_logic);
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of s_axi_aclk : signal is "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn";
end;
architecture rtl of ntt_axi is
  signal wr_fire, ar_fire, start, busy, done_p, bvalid, rvalid, done_r, rpend, rmem, rst_sel : std_logic := '0';
  signal h_addr : std_logic_vector(7 downto 0); signal h_rdata : std_logic_vector(15 downto 0);
  signal rdata : std_logic_vector(31 downto 0) := (others => '0');
begin
  wr_fire <= s_axi_awvalid and s_axi_wvalid and not bvalid;
  ar_fire <= s_axi_arvalid and not rvalid and not rpend and not wr_fire;
  s_axi_awready <= wr_fire; s_axi_wready <= wr_fire; s_axi_arready <= ar_fire;
  s_axi_bresp <= "00"; s_axi_rresp <= "00"; s_axi_bvalid <= bvalid; s_axi_rvalid <= rvalid; s_axi_rdata <= rdata;
  start  <= wr_fire and not s_axi_awaddr(10) and not s_axi_awaddr(2) and s_axi_wdata(0);
  h_addr <= s_axi_awaddr(9 downto 2) when wr_fire = '1' else s_axi_araddr(9 downto 2);

  core : entity work.ntt_core port map(s_axi_aclk, s_axi_aresetn, start, busy, done_p,
           wr_fire and s_axi_awaddr(10), h_addr, s_axi_wdata(15 downto 0), h_rdata);

  process(s_axi_aclk) begin
    if rising_edge(s_axi_aclk) then
      if s_axi_aresetn = '0' then
        bvalid <= '0'; rvalid <= '0'; rpend <= '0'; done_r <= '0';
      else
        if wr_fire = '1' then bvalid <= '1'; elsif s_axi_bready = '1' then bvalid <= '0'; end if;
        if start = '1' then done_r <= '0'; elsif done_p = '1' then done_r <= '1'; end if;
        if ar_fire = '1' then rpend <= '1'; rmem <= s_axi_araddr(10); rst_sel <= s_axi_araddr(2); end if;
        if rpend = '1' then
          rpend <= '0'; rvalid <= '1';
          if rmem = '1' then rdata <= std_logic_vector(resize(signed(h_rdata), 32));
          elsif rst_sel = '1' then rdata <= (31 downto 2 => '0') & done_r & busy;
          else rdata <= (others => '0'); end if;
        elsif rvalid = '1' and s_axi_rready = '1' then rvalid <= '0'; end if;
      end if;
    end if;
  end process;
end;
