KYBER ?= kyber
$(KYBER):
	git clone --depth 1 https://github.com/pq-crystals/kyber.git $(KYBER)
vectors: $(KYBER)
	gcc -O2 -DKYBER_K=3 -I$(KYBER)/ref gen_vectors.c $(KYBER)/ref/ntt.c $(KYBER)/ref/reduce.c -o gen_vectors
	./gen_vectors
	cp zeta_rom.vhd ../rtl/zeta_rom.vhd
