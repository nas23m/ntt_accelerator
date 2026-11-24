/* On Kria (Linux): gcc -O2 -DKYBER_K=3 -I../ref/kyber/ref ntt_hw_test.c ../ref/kyber/ref/{ntt,reduce}.c -o t; sudo ./t */
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include "params.h"
#include "ntt.h"
#include "reduce.h"
#define BASE 0xA0000000UL
int main(void){
  int fd=open("/dev/mem",O_RDWR|O_SYNC); volatile uint32_t *r=mmap(0,4096,PROT_READ|PROT_WRITE,MAP_SHARED,fd,BASE);
  int16_t a[256],g[256]; int bad=0; srand(1);
  for(int i=0;i<256;i++){ a[i]=rand()%KYBER_Q; r[0x100+i]=(uint16_t)a[i]; }
  r[0]=1; while(r[1]&1);
  for(int i=0;i<256;i++) g[i]=(int16_t)r[0x100+i];
  ntt(a); for(int i=0;i<256;i++) if(g[i]!=barrett_reduce(a[i])) bad++;
  printf(bad?"FAIL %d\n":"PASS\n",bad); return bad!=0;
}
