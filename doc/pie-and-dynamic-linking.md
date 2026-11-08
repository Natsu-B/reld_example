# PIEと動的リンク

本文で扱ったのは、アドレスを`0x400000`から固定で決める、静的リンクの実行ファイルでした。しかし、今のUbuntuで`gcc hello.c`とすると、できあがる`a.out`は**PIE**（Position Independent Executable、位置独立実行ファイル）で、しかも**動的リンク**された実行ファイルになります。reldはどちらにも対応していませんが、この資料では、静的リンクと比べて何が変わるのかを見ておきます。

ここでは、次の`hello.c`を、普通に`gcc`でコンパイルしたものを使います。

```c
#include <stdio.h>

int main() {
    printf("Hello, world!\n");
}
```

```console
$ gcc -O2 -o hello_pie hello.c
$ readelf -hW hello_pie
  Type:                              DYN (Position-Independent Executable file)
  Entry point address:               0x1080
```

## PIE

### 実行のたびに変わるアドレス

これまでの実行ファイルは、ELFヘッダの`Type`が`EXEC`で、`_start`が必ず`0x401000`のような決まったアドレスに置かれていました。PIEでは`Type`が`DYN`になり、プログラムヘッダの`LOAD`も0番地から始まっています。

```console
$ readelf -lW hello_pie
  Type           Offset   VirtAddr           FileSiz  MemSiz   Flg Align
  PHDR           0x000040 0x0000000000000040 0x0002d8 0x0002d8 R   0x8
  INTERP         0x000318 0x0000000000000318 0x00001c 0x00001c R   0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x000000 0x0000000000000000 0x000628 0x000628 R   0x1000
  LOAD           0x001000 0x0000000000001000 0x000179 0x000179 R E 0x1000
  LOAD           0x002000 0x0000000000002000 0x0000ec 0x0000ec R   0x1000
  LOAD           0x002db8 0x0000000000003db8 0x000258 0x000260 RW  0x1000
  DYNAMIC        0x002dc8 0x0000000000003dc8 0x0001f0 0x0001f0 RW  0x8
...
  GNU_RELRO      0x002db8 0x0000000000003db8 0x000248 0x000248 R   0x1
```

PIEのアドレスは、実際のアドレスではなく、読み込んだ先頭からの位置を表しています。カーネルはPIEを実行のたびに違う先頭アドレス（ベースアドレス）に読み込み、プログラムの実際のアドレスは「ベースアドレス＋ELFに書かれたアドレス」になります。こうしてアドレスを毎回変えておくと、攻撃者が関数やデータのアドレスを決め打ちしにくくなります（ASLR）。

### ベースアドレスが変わっても動くコード

ベースアドレスが毎回変わるので、命令の中に絶対アドレスを埋め込むことはできません。本文の小さな例では、`-fno-pie`を付けてコンパイルしていたので、`mov $0x402000,%edi`のように、文字列の絶対アドレスを命令に埋め込んでいました（`R_X86_64_32`）。`-fno-pie`の代わりに`-fpie`を付けると、コンパイラは`lea 0x0(%rip),%rdi`のようなRIP相対（次の命令の先頭からの距離で指す書き方）の命令を使い、再配置も`R_X86_64_PC32`になります。RIP相対の距離は、命令と文字列が一緒に動くかぎり変わらないので、ベースアドレスがどこになっても書き換える必要がありません。小さな例の`main.o`をPIEとしてリンクしようとすると、GNU ldはこの`R_X86_64_32`を見つけて、`-fPIE`で作り直すようにとエラーにします。

```console
$ ld -pie -o hello_pie start.o main.o greet.o libgreet.a
ld: main.o: relocation R_X86_64_32 against `.rodata.str1.1' can not be used when making a PIE object; recompile with -fPIE
```

### 動的再配置

ただし、データの中に置かれたポインタは、そうはいきません。例えば`.init_array`には、コンストラクタ関数のアドレスそのものが入っています。この値はベースアドレスによって変わるので、リンク時には決められません。

そこでGNU ldは、実行ファイルの中に**動的再配置**を残しておき、実行時に書き換えてもらいます。`hello_pie`の`.rela.dyn`を見ると、次のようになっています。

```console
$ readelf -rW hello_pie
Relocation section '.rela.dyn' at offset 0x550 contains 8 entries:
    Offset             Info             Type               Symbol's Value  Symbol's Name + Addend
0000000000003db8  0000000000000008 R_X86_64_RELATIVE                         1160
0000000000003dc0  0000000000000008 R_X86_64_RELATIVE                         1120
0000000000004008  0000000000000008 R_X86_64_RELATIVE                         4008
0000000000003fd8  0000000100000006 R_X86_64_GLOB_DAT      0000000000000000 __libc_start_main@GLIBC_2.34 + 0
...
Relocation section '.rela.plt' at offset 0x610 contains 1 entry:
    Offset             Info             Type               Symbol's Value  Symbol's Name + Addend
0000000000003fd0  0000000300000007 R_X86_64_JUMP_SLOT     0000000000000000 puts@GLIBC_2.2.5 + 0
```

1行目の`R_X86_64_RELATIVE`は、「`0x3db8`（`.init_array`の先頭）に、ベースアドレス＋`0x1160`を書け」という意味です。`R_X86_64_RELATIVE`はシンボルを使わないので、最後の列には補正値の`1160`だけが出ています。`0x1160`はコンストラクタ関数のアドレスで、ベースアドレスがわかれば計算できます。静的リンクでは、リンカが`R_X86_64_64`を`S + A`（シンボルのアドレス＋補正値）で計算して書き込んでいましたが、PIEでは`S`がベースアドレスの分だけ決まらないので、その足し算を実行時に回します。IFUNCの`R_X86_64_IRELATIVE`も、この動的再配置の一種です。

なお、`gcc -static-pie`とすると、静的リンクのPIEも作れます。この場合は動的リンカがいないので、glibcの起動処理（`_dl_relocate_static_pie`）が、`main`の前に自分自身の`R_X86_64_RELATIVE`を適用します。`hello.c`を`-static-pie`でリンクすると、`R_X86_64_RELATIVE`が1094個、`R_X86_64_IRELATIVE`が22個残りました。

## 動的リンク

### 動的リンカ

`hello_pie`の`readelf -lW`には、`INTERP`と`DYNAMIC`という、固定アドレスの静的リンクの実行ファイルにはなかったプログラムヘッダがありました。

`INTERP`には、**動的リンカ**のパス`/lib64/ld-linux-x86-64.so.2`が書かれています。カーネルは`INTERP`を見つけると、プログラムだけでなく動的リンカもメモリに読み込み、プログラムの`Entry point`ではなく、動的リンカの入口から実行を始めます。動的リンカは、おおまかに次の順番で仕事をします。

1. 自分自身の再配置を済ませる（動的リンカ自身も、どのアドレスに読み込まれるかわからないため）
2. `DYNAMIC`が指す`.dynamic`を読み、必要な共有ライブラリ（`NEEDED`）を探して読み込む
3. プログラムと共有ライブラリの動的再配置を適用する
4. 共有ライブラリの`.init_array`などを呼び出す
5. プログラムの`Entry point`（ベースアドレス＋`0x1080`）にある`_start`へジャンプする

`.dynamic`は、動的リンカに渡す情報の一覧です。

```console
$ readelf -dW hello_pie
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
 0x000000000000000c (INIT)               0x1000
 0x0000000000000019 (INIT_ARRAY)         0x3db8
...
 0x0000000000000006 (SYMTAB)             0x3d8
 0x0000000000000007 (RELA)               0x550
 0x0000000000000017 (JMPREL)             0x610
 0x000000000000001e (FLAGS)              BIND_NOW
 0x000000006ffffffb (FLAGS_1)            Flags: NOW PIE
...
```

`NEEDED`が必要な共有ライブラリ、`RELA`と`JMPREL`が先ほどの`.rela.dyn`と`.rela.plt`の場所です。`SYMTAB`は、動的リンク用のシンボル表`.dynsym`を指しています。これまで見てきた`.symtab`は、カーネルや起動処理が読まないものでした。一方`.dynsym`は、動的リンカが実行時にシンボルを探すために使います。

### 共有ライブラリのシンボルとGOT

3の動的再配置のうち、`R_X86_64_RELATIVE`はベースアドレスを足すだけです。一方、`R_X86_64_GLOB_DAT`と`R_X86_64_JUMP_SLOT`は、共有ライブラリのシンボルを参照するための再配置です。動的リンカは、`libc.so.6`などの`.dynsym`から`__libc_start_main`や`puts`を探します。見つけたアドレスは、GOT（Global Offset Table、アドレスを入れておく表）の欄（`0x3fd8`や`0x3fd0`）に書き込みます[^puts]。

つまり、静的リンクではリンカがリンク時に行っていたシンボル解決の一部を、動的リンクでは動的リンカが実行時に行っています。共有ライブラリがどのアドレスに読み込まれるかは実行時までわからないので、プログラムのコードは本文の「glibcの静的リンク」で見たのと同じように、GOTの欄を経由して共有ライブラリの関数や変数を参照します。

### PLTと遅延バインディング

共有ライブラリの`puts`を呼び出すときは、PLT（Procedure Linkage Table、GOTの欄を経由して関数へ飛ぶ中継のコード）を経由します。`hello_pie`の`puts@plt`は次のようになっています。

```console
$ objdump -d hello_pie
0000000000001050 <puts@plt>:
    1050:  f3 0f 1e fa             endbr64
    1054:  ff 25 76 2f 00 00       jmp    *0x2f76(%rip)        # 3fd0 <puts@GLIBC_2.2.5>
```

GOTの欄`0x3fd0`に書かれたアドレスへ飛ぶだけ、という作りは、静的glibcでIFUNCを呼ぶために使うIPLTスタブ（本文の「glibcの静的リンク」）と同じです。違うのは、その欄を誰がいつ埋めるかです。

動的リンクでは、もともと**遅延バインディング**（lazy binding）という仕組みが使えます。起動時にはGOTの欄にPLTの中のアドレスを入れておき、関数を初めて呼んだときに動的リンカのリゾルバへ飛ばして、そこで関数を探してGOTの欄を書き換えます。2回目からは、書き換わった欄から直接関数へ飛びます。遅延バインディングで使うPLTには、GOTの欄から飛ぶ命令のほかに、動的リンカへ処理を渡す命令も用意されていて、最初はGOTの欄にそちらのアドレスを入れておきます。使わない関数を探さずに済むので、起動が速くなります。

ただし、`hello_pie`の`.dynamic`には`BIND_NOW`が付いています。Ubuntuのgccは既定でリンカに`-z now`を渡すので、動的リンカは起動時にすべての欄を埋めます。埋め終わったあとは、`GNU_RELRO`が示す範囲（GOTを含む）を読み取り専用にして、GOTを書き換えられないようにします。動的再配置が終わった範囲を読み取り専用にするこの仕組みを、RELRO（relocation read-only）と呼びます。

静的リンクとまとめて比べると、次のようになります。

**GOTの欄を埋める時期**

|  | 静的リンク | 動的リンク（BIND_NOW） | 動的リンク（遅延バインディング） |
|---|---|---|---|
| 誰が埋めるか | リンカ（IFUNCの欄は__libc_start_main） | 動的リンカ | 動的リンカ |
| いつ埋めるか | リンク時（IFUNCの欄はmainの前） | 起動時（mainの前） | 関数の欄は、その関数を初めて呼んだとき |
| main開始後の状態 | 書き換わらない | 読み取り専用になっている | まだ呼んでいない関数の欄は、呼んだときに書き換わる |

### reldに足りないもの

PIEと動的リンクに対応するには、reldは少なくとも次のものを作れるようになる必要があります。

- `ET_DYN`の実行ファイルと、0番地から始まるレイアウト
- `.interp`、`.dynamic`、`.dynsym`と`.dynstr`、シンボルを速く探すための`.gnu.hash`
- `.rela.dyn`と`.rela.plt`の動的再配置、遅延バインディング用の`.plt`と`.got.plt`
- `puts@GLIBC_2.2.5`のようなシンボルのバージョン（`.gnu.version`と`.gnu.version_r`）

`hello_pie`の`readelf -lW`で最初の`LOAD`を見ると、このうち`.interp`、`.dynsym`、`.dynstr`、`.gnu.hash`、`.gnu.version`、`.gnu.version_r`、`.rela.dyn`、`.rela.plt`が入っています。`.dynamic`と`.got`は書き込める`LOAD`に、`.plt`は実行できる`LOAD`に入ります（`-z now`でリンクしているので、`.got.plt`は`.got`にまとめられています）。

```console
$ readelf -lW hello_pie
...
   02     .interp .note.gnu.property .note.gnu.build-id .note.ABI-tag .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt
...
```

固定アドレスの静的リンクでは、リンカが通常のコードやデータのアドレスを決め、glibcの起動処理がIFUNCの解決やTLSの準備、コンストラクタの呼び出しをしていました。動的リンクでは、リンク時に決めきれないアドレスの計算を、実行時の動的リンカに任せます。リンカは、実行時の処理に必要な情報を、これらのセクションに書き残します。

[^puts]: `hello.c`は`printf`を呼んでいますが、書式に`%`を含まず改行で終わる文字列なので、GCCが`puts`の呼び出しに置き換えています。
