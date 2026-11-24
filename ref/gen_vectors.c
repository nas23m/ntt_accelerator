/* Generates test vectors + zeta ROM from the pq-crystals Kyber reference (ntt.c, reduce.c). */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "params.h"
#include "ntt.h"
#include "reduce.h"
#define NV 64
static uint32_t s = 12345;
static uint32_t rnd(void){ s ^= s<<13; s ^= s>>17; s ^= s<<5; return s; }
int main(void){
  FILE *fi=fopen("vec_in.mem","w"), *fo=fopen("vec_exp.mem","w"), *fz=fopen("zeta_rom.vhd","w");
  for(int v=0; v<NV; v++){
    int16_t a[256];
    for(int i=0;i<256;i++){
      switch(v){
        case 0: a[i]=0; break;
        case 1: a[i]=KYBER_Q-1; break;
        case 2: a[i]=-(KYBER_Q-1)/2; break;
        case 3: a[i]=(i&1)?(KYBER_Q-1):0; break;
        case 4: a[i]=i; break;
        default: a[i]=(v&1)? (int16_t)(rnd()%KYBER_Q) : (int16_t)((int)(rnd()%KYBER_Q)-KYBER_Q/2);
      }
      fprintf(fi,"%04x\n",(uint16_t)a[i]);
    }
    ntt(a);
    for(int i=0;i<256;i++){ fprintf(fo,"%04x\n",(uint16_t)barrett_reduce(a[i])); }
  }
  fprintf(fz,"-- Generated from pq-crystals zetas[] (Montgomery domain)\nlibrary ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;\nentity zeta_rom is port(clk: in std_logic; addr: in std_logic_vector(6 downto 0); q: out std_logic_vector(15 downto 0)); end;\narchitecture rtl of zeta_rom is\ntype t is array(0 to 127) of std_logic_vector(15 downto 0);\nconstant rom: t := (\n");
  for(int i=0;i<128;i++) fprintf(fz,"x\"%04x\"%s\n",(uint16_t)zetas[i],i<127?",":"");
  fprintf(fz,");\nbegin\nprocess(clk) begin if rising_edge(clk) then q <= rom(to_integer(unsigned(addr))); end if; end process;\nend;\n");
  fclose(fi);fclose(fo);fclose(fz);return 0;
}
