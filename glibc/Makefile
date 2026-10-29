CC := gcc
LD := ../reld/target/debug/reld

# printf が __printf_chk に置き換わらないように、保護機能を切ってコンパイルする
CFLAGS := -O2 -fno-pie -fno-stack-protector -U_FORTIFY_SOURCE \
          -fcf-protection=none -fno-asynchronous-unwind-tables

# reld は -L や -l に対応していないので、crt*.o と静的ライブラリをフルパスで渡す。
# nix develop では flake.nix が環境変数で場所を教える。それ以外では gcc に聞く。
CRT_DIR  ?= $(abspath $(or $(GLIBC_CRT_DIR),$(dir $(shell $(CC) -print-file-name=crt1.o))))
LIBC_DIR ?= $(abspath $(or $(GLIBC_STATIC_LIB_DIR),$(dir $(shell $(CC) -print-file-name=libc.a))))
GCC_DIR  ?= $(abspath $(or $(LIBGCC_DIR),$(dir $(shell $(CC) -print-libgcc-file-name))))

START := $(CRT_DIR)/crt1.o $(CRT_DIR)/crti.o $(GCC_DIR)/crtbeginT.o
# gcc -static と同じく、互いに参照し合うライブラリを --start-group でまとめる
LIBS  := --start-group $(GCC_DIR)/libgcc.a $(GCC_DIR)/libgcc_eh.a $(LIBC_DIR)/libc.a --end-group
END   := $(GCC_DIR)/crtend.o $(CRT_DIR)/crtn.o

INPUTS = $(START) hello_glibc.o $(LIBS) $(END)

TRACE ?= got

.PHONY: all run trace map gnu compare clean

all: hg

hello_glibc.o: hello_glibc.c
	$(CC) $(CFLAGS) -c $< -o $@

hg: hello_glibc.o
	$(LD) -o $@ $(INPUTS)

run: hg
	./hg

# 各段階の結果を表示する（例：make trace TRACE=layout）
trace: hello_glibc.o
	$(LD) -o hg $(INPUTS) --trace $(TRACE)

map: hello_glibc.o
	$(LD) -o hg $(INPUTS) -Map hg.map

# 同じ入力を GNU ld でリンクする
gnu: hello_glibc.o
	ld -static -o hg_ld $(INPUTS)

# reld と GNU ld の出力を比べる
compare: hg gnu
	./hg
	./hg_ld
	@echo "size: reld $$(stat -c %s hg), GNU ld $$(stat -c %s hg_ld)"
	@echo "IRELATIVE: reld $$(readelf -rW hg | grep -c IRELATIVE), GNU ld $$(readelf -rW hg_ld | grep -c IRELATIVE)"

clean:
	rm -f *.o hg hg_ld hg.map
