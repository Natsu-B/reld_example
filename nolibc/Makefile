CC := gcc
LD := ../reld/target/debug/reld
AR := ar

CFLAGS := -Wall -Wextra -O1 -ffreestanding -fno-pie \
          -fno-stack-protector \
          -fno-asynchronous-unwind-tables \
          -fcf-protection=none \
          -fno-omit-frame-pointer

TARGET := hello

OBJS := start.o main.o greet.o
LIB  := libgreet.a

TRACE ?= inputs,archive

.PHONY: all objects archive run trace map order weak hook multi undef far clean

all: $(TARGET)

objects: $(OBJS) put.o exit.o

archive: $(LIB)

$(TARGET): $(OBJS) $(LIB)
	$(LD) -o $@ $^

$(LIB): put.o exit.o
	$(AR) rcs $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(CC) -c $< -o $@

run: $(TARGET)
	./$(TARGET)

# 各段階の結果を表示する（例：make trace TRACE=layout）
trace: $(OBJS) $(LIB)
	$(LD) -o $(TARGET) $^ --trace $(TRACE)

# リンクマップを hello.map に書き出す
map: $(OBJS) $(LIB)
	$(LD) -o $(TARGET) $^ -Map hello.map

# ライブラリを先に書くと undefined symbol になる（失敗するのが正しい）
order: $(OBJS) $(LIB)
	-$(LD) -o order $(LIB) $(OBJS)

# weak な greet だけのときと、strong な greet もあるとき
weak: start.o main.o weak_greet.o greet.o $(LIB)
	$(LD) -o weak1 start.o main.o weak_greet.o $(LIB) && ./weak1
	$(LD) -o weak2 start.o main.o weak_greet.o greet.o $(LIB) && ./weak2

# 定義のない weak 参照は 0 になる
hook: start.o main2.o greet.o $(LIB)
	$(LD) -o hook start.o main2.o greet.o $(LIB) --trace symbols && ./hook

# strong な定義が2つある（失敗するのが正しい）
multi: $(OBJS) $(LIB)
	-$(LD) -o multi start.o main.o greet.o greet.o $(LIB)

# 定義が見つからない（失敗するのが正しい）
undef: start.o main.o greet.o
	-$(LD) -o undef start.o main.o greet.o

# 文字列を 4GiB より上に置くと 32 ビットに収まらない（失敗するのが正しい）
far: $(OBJS) $(LIB) far.ld
	-$(LD) -T far.ld -o far $(OBJS) $(LIB)

clean:
	rm -f *.a *.o $(TARGET) order weak1 weak2 hook multi undef far hello.map
