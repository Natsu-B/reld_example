# ほかのリンカとの違い

本文では、reldとGNU ldの動きが同じところを「リンカは」と書きました。ここでは、LLVMのリンカであるlldと、moldで動きが違うところをまとめます。確かめたのは、Ubuntu 24.04のGNU ld 2.42、lld 18.1.3、mold 2.30.0です。例はreld_exampleの[`nolibc`](../nolibc)と[`glibc`](../glibc)ディレクトリのものです。

## ライブラリの順番

GNU ldとreldは、各ライブラリを読む時点で未解決のシンボルをもとに取り込むものを決め、後ろのファイルを読んだあとで前のライブラリに戻りません。そのため、ライブラリを先に書くとエラーになります。

```console
$ ld -o hello libgreet.a start.o main.o greet.o
ld: main.o: in function `run':
main.c:(.text+0x14): undefined reference to `exit_with'
...
$ reld -o hello libgreet.a start.o main.o greet.o
Error: undefined symbol: exit_with in file: main.o
```

lldとmoldは、後ろのファイルで必要になったシンボルでも、前に読んだライブラリから取り込みます。同じ順番でもリンクできます。

```console
$ ld.lld -o hello libgreet.a start.o main.o greet.o && ./hello
Hello, linker!
$ mold -o hello libgreet.a start.o main.o greet.o && ./hello
Hello, linker!
```

reld_exampleの`nolibc`ディレクトリでは、`make order`がreldで、`make order LD=ld.lld`がlldでこの順番を試します。

## --start-groupと--end-group

静的glibcでは`libc.a`と`libgcc.a`が互いのシンボルを必要とするので、GNU ldとreldでは、`--start-group`と`--end-group`で囲まないとリンクできません。

```console
$ ld -static -o hg crt1.o crti.o crtbeginT.o hello_glibc.o \
    libgcc.a libgcc_eh.a libc.a crtend.o crtn.o   # 実際は各ファイルをフルパスで指定（glibc/Makefileを参照）
ld: libc.a(printf_fp.o): in function `__printf_fp_buffer_1.isra.0':
(.text+0x1d8): undefined reference to `__unordtf2'
...
```

lldとmoldは、もともと前に読んだライブラリからも取り込むので、グループがなくてもこのリンクは通ります。`--start-group`と`--end-group`を渡しても、エラーにはなりません。

`--start-group`に対応していないリンカでは、`libc.a libgcc.a libgcc_eh.a libc.a`のように同じライブラリを2回書く必要があります。ただし、この方法は、2回目の`libc.a`がさらに`libgcc.a`の別のオブジェクトファイルを必要とすると、また足りなくなります。グループなら、何周必要でもリンカが繰り返してくれます。

## 索引のないアーカイブ

`ar rcS`で作った、シンボル索引（armap）のない`.a`を渡したときの動きです。

| リンカ | 結果 |
|---|---|
| GNU ld 2.42 | `archive has no index; run ranlib to add one`のエラー |
| reld | 中のオブジェクトファイルをすべて読み、自分で索引を作ってリンクする |
| lld 18.1.3 | リンクできる |
| mold 2.30.0 | リンクできる |

GNU ldも2.47からは、既定で索引のない`.a`を受け付け、自分で索引を作るようになりました（binutilsの`ld/NEWS`の「Changes in 2.47」）。`--no-link-mapless`を付けると、従来どおりエラーになります。

## 再配置の値が収まらない場合

`far.ld`で文字列を4GiB以上のアドレスに置くと、`R_X86_64_32`の値が32ビットに収まりません（reld_exampleの`make far`）。

- reldは、最初に見つけた1か所でエラーにします。
- GNU ldは`relocation truncated to fit`として、収まらない3か所をすべて表示します（出力は「再配置の計算コードと範囲チェック」に載せました）。
- lldもGNU ldと同じように、収まらない箇所を続けて表示します。

```console
$ ld.lld -T far.ld -o far start.o main.o greet.o libgreet.a
ld.lld: error: main.o:(function run: .text+0x5): relocation R_X86_64_32 out of range: 4294967307 is not in [0, 4294967295]; references section '.rodata.str1.1'
>>> referenced by main.c
...
```

- moldが読めるリンカスクリプトは一部の命令だけなので、`far.ld`は読み込む段階でエラーになります。

```console
$ mold -T far.ld -o far start.o main.o greet.o libgreet.a
mold: fatal: far.ld:1: ENTRY(_start)
                ^ unknown linker script token
```

## 多重定義のエラーの文面

同じ`greet.o`を2回渡すと、どのリンカも多重定義のエラーにしますが、文面は違います。

```console
$ reld -o multi start.o main.o greet.o greet.o libgreet.a
Error: multiple definition of symbol: greet in files: greet.o and greet.o
$ ld.lld -o multi start.o main.o greet.o greet.o libgreet.a
ld.lld: error: duplicate symbol: greet
>>> defined at greet.c
>>>            greet.o:(greet)
...
$ mold -o multi start.o main.o greet.o greet.o libgreet.a
mold: error: duplicate symbol: greet.o: greet.o: greet
```

GNU ldでは``multiple definition of `greet'``になります。
