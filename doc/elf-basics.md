# ELFの基礎とシンボル解決の細かい規則

本文の「リンカは何をしているか」「オブジェクトファイルを集める」「シンボル解決」を補う資料です。例はreld_exampleの`nolibc`ディレクトリのものです。

## リンクに必要なELFの基礎

本文の小さな例は、`_start`（`start.s`）から`run`（`main.c`）を呼び、`run`が`greet`（`greet.c`）と`exit_with`（`exit.s`）を呼ぶプログラムです。[`nolibc`](../nolibc)ディレクトリで`make`を実行すると、`main.o`などのオブジェクトファイルと、リンクした`hello`ができます。`main.o`の`run`を逆アセンブルすると、次のようになります。

```console
$ objdump -d main.o
0000000000000000 <run>:
   0:  55                push   %rbp
   1:  48 89 e5          mov    %rsp,%rbp
   4:  bf 00 00 00 00    mov    $0x0,%edi
   9:  e8 00 00 00 00    call   e <run+0xe>
   e:  bf 00 00 00 00    mov    $0x0,%edi
  13:  e8 00 00 00 00    call   18 <run+0x18>
  18:  5d                pop    %rbp
  19:  c3                ret
```

`call`の後ろの4バイトや、文字列のアドレスを入れる`4:`の`mov`の後ろが0のままなのは、まだアドレスが決まっていないからです。`main.o`と`hello`は、どちらもELF形式のファイルです。ELFにはコードやデータのほかに、シンボルや再配置の情報も格納されています。ここでは、同じプログラムを`readelf`で調べながら、リンクに使う情報を確認します。

### セクション

ELFファイルのコードやデータは、用途ごとの領域に分かれています。この領域を**セクション**と呼びます。`readelf -SW`で、セクションの一覧を表示できます。以下は`main.o`の出力から、説明に使う行と列を抜粋したものです。

```console
$ readelf -SW main.o
  [Nr] Name              Type       Size   Flg Al
  [ 1] .text             PROGBITS   00001a  AX  1
  [ 2] .rela.text        RELA       000048   I  8
  [ 3] .data             PROGBITS   000000  WA  1
  [ 4] .bss              NOBITS     000000  WA  1
  [ 5] .rodata.str1.1    PROGBITS   000007 AMS  1
  [ 8] .symtab           SYMTAB     000090      8
```

`.text`には機械語の命令、`.rodata.str1.1`には文字列`"linker"`が入っています。`.data`は初期値のある書き込み可能なデータ、`.bss`は実行時に0で初期化するデータのためのセクションです。この例の`.data`と`.bss`は大きさが0になっています。

`Size`はセクションの大きさを16進数で表します。`Flg`の`A`は実行時にメモリへ置くこと、`W`は書き込み可能、`X`は実行可能であることを示します。`M`と`S`は、同じ文字列を1つにまとめてよいことを表す`SHF_MERGE`と`SHF_STRINGS`です（[セクション配置の細かい規則](layout-details.md)の「.textと.rodata」）。ほかの文字もありますが、ここでは`A`、`W`、`X`に注目します。`Al`はアラインメントで、リンカはセクションをこの値の倍数のアドレスに置きます。

`.rela.text`には`.text`を書き換えるための再配置情報、`.symtab`にはシンボル表が入っています。

GCCは文字列を`.rodata.str1.1`のような細かい名前のセクションに入れることがあります。リンカはこれを「`.rodata.`で始まるものはまとめて`.rodata`へ」という規則（リンカスクリプト。本文の「セクションの配置」で説明します）で集めます。

### シンボル表

シンボル表には関数や変数などの名前と、その定義についての情報が記録されています。`readelf -sW`で表示できます。次の出力は、`main.c`で定義した`run`（`_start`から呼ばれる関数）と、`run`から呼ぶ`greet`と`exit_with`を抜粋したものです。

```console
$ readelf -sW main.o
   Num:    Value          Size Type    Bind   Vis      Ndx Name
     3: 0000000000000000    26 FUNC    GLOBAL DEFAULT    1 run
     4: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND greet
     5: 0000000000000000     0 NOTYPE  GLOBAL DEFAULT  UND exit_with
```

`run`の`Ndx`は1で、先ほどのセクション番号1、つまり`.text`に定義があることを示しています。`Value`は0です。通常のオブジェクトファイルのセクション内に定義されたシンボルでは、この値はセクションの先頭からの位置を表します。`run`の実行時のアドレスは`.text`をどこに置くかが決まってから求めます。

`greet`と`exit_with`の`Ndx`は、未定義を表す`UND`（undefined）です。`main.o`にはこれらの定義がないため、リンカは他のオブジェクトファイルから定義を探します。

`Bind`の`GLOBAL`は、他のファイルからも参照できるシンボルであることを示します。ファイル内だけで使うシンボルは`LOCAL`になり、例えばCで`static`を付けた関数が該当します。もう1つ`WEAK`という種類があり、本文の「シンボル解決」とこの資料の後半で説明します。

### 再配置情報

本文で見た`main.o`の3か所の書き換え位置は、`.rela.text`に記録されています。`readelf -rW`の出力から、位置、種類、参照先、補正値の列を抜粋します。

```console
$ readelf -rW main.o
    Offset             Type               Symbol's Name + Addend
0000000000000005  R_X86_64_32            .rodata.str1.1 + 0
000000000000000a  R_X86_64_PLT32         greet - 4
0000000000000014  R_X86_64_PLT32         exit_with - 4
```

各行が1つの再配置エントリです。`Offset`は、書き換える位置を`.text`の先頭からのバイト数で表します。

`greet`の行で確かめてみます。逆アセンブルの`9:`にあった`call greet`は、`e8 00 00 00 00`の5バイトでした。先頭の`e8`が`call`命令を表し、残りの4バイトに飛び先までの距離が入ります。この4バイトは`0x9 + 1 = 0xa`から始まるので、`Offset`は`0xa`になっています。同じように、`exit_with`の`call`は`13:`にあるので`0x14`、文字列のアドレスを入れる`mov`は`4:`の`bf`の後ろなので`0x5`です。

`Type`は値の計算方法と書き込む幅を指定します。この例の`R_X86_64_32`はアドレスを32ビットで書き込み、`R_X86_64_PLT32`は関数呼び出しのための相対値を32ビットで書き込みます。`Symbol's Name`が参照するシンボル、`Addend`が計算に加える補正値です。

`greet - 4`は、`greet`の定義が4バイト手前にあるという意味ではありません。次の図のように、CPUは`call`の4バイトの値を、**次の命令の先頭**（`0xe`）からの距離として使います。一方、再配置の位置`Offset`は、書き換える4バイトの先頭（`0xa`）です。両者は書き換える幅の4バイトだけずれているので、その分を補正値の`-4`で埋め合わせます。

**call greetの書き換える位置と、CPUが距離を測る起点**

```
 Offset  0x9   0xa   0xb   0xc   0xd   0xe
        +-----+-----+-----+-----+-----+-----
        | e8  | 00  | 00  | 00  | 00  | bf ...   (次の命令)
        +-----+-----+-----+-----+-----+-----
         call  ^                       ^
               |                       |
               P: 書き換える位置        CPUが距離を測る起点 = P + 4

 書き込む値 = greet - (P + 4) = greet + (-4) - P
```

実際の数値での計算は、本文の「再配置の適用」で確かめています。

### 必要なオブジェクトファイルの取り出し方

リンカは、コマンドラインのファイルを左から順に読みながら、2つの集合を更新していきます。

- **定義済み**のシンボル：これまでに読んだファイルが定義しているシンボル
- **未解決**のシンボル：これまでに読んだファイルが使っているのに、まだ定義が見つかっていないシンボル

`.o`が来たら、それは必ず取り込み、2つの集合を更新します。`.a`が来たら、索引を引いて「未解決のシンボルを定義しているオブジェクトファイル」だけを取り込みます。取り込んだオブジェクトファイルがさらに別のシンボルを必要とすることがあるので、新しく取り込むものがなくなるまで索引を引き直します。

**src/symbols/extract.rs（抜粋・簡略化）**

```rust
InputFile::Archive(mut archive) => {
    loop {
        let mut loaded = false;
        for entry in &archive.entries {           // 索引を先頭から
            let member_index = entry.member_index;
            if archive.extracted[member_index]
                || !unresolved.contains_key(entry.symbol) {
                continue;                         // 取り込み済みか、不要
            }
            let object = object::parse(/* オブジェクトファイルのバイト列 */)?;
            archive.extracted[member_index] = true;
            update_symbol_sets(&object, &mut defined, &mut unresolved);
            files.push(object);                   // 取り込む
            loaded = true;
        }
        if !loaded { break; }                     // 増えなくなったら次の入力へ
    }
}
```

例で追ってみます。`start.o`を読むと`run`が、`main.o`を読むと`greet`と`exit_with`が未解決になります。`main.o`が`run`を定義しているので`run`は定義済みに移り、`greet.o`を読むと`greet`が定義済みに移って、代わりに`put`が未解決に加わります。そこで`libgreet.a`の索引を引くと、`put.o`と`exit.o`の両方が必要だとわかります。`--trace archive`の出力は、この記録です。

```console
$ reld -o hello start.o main.o greet.o libgreet.a --trace archive
[archive]
MEMBER <- FILE (SYMBOL)
libgreet.a(put.o) <- greet.o (put)
libgreet.a(exit.o) <- main.o (exit_with)
```

「`put.o`は、`greet.o`が`put`を必要としたから取り込んだ」と読みます。

ここで気をつけたいのは、取り込む単位が関数ではなくオブジェクトファイルだという点です。`put.o`に関数が10個入っていれば、使うのが`put`だけでも、10個すべてが実行ファイルに入ります。glibcの`libc.a`は2211個のオブジェクトファイルに細かく分かれているので、必要な部分だけを取り込めます。

## シンボル解決の仕組み

オブジェクトファイルが集まったら、次はシンボルごとに、どの定義を使うかを決めます。この段階では、まだアドレスは決まっていません。ここで決めるのは「`greet`は`greet.o`の`.text`の先頭にある」という対応だけで、その`.text`がどこに置かれるかは本文の「セクションの配置」で決まります。

### 定義を選ぶ規則

規則は次のとおりです。

- `LOCAL`のシンボルは、そのファイルの中だけで解決します。別々のファイルにある`static`関数が同じ名前でも、互いに干渉しません
- `GLOBAL`のシンボルは、全ファイルを通して1つの定義に決めます
- 同じシンボルの定義が複数あるとき、**strong**（普通の定義）は**weak**（弱い定義）に勝ちます
- strongが2つあればエラー、weakしかなければ最初に見つかったweakを使います
- どこにも定義がなければエラーです。ただし、weakな参照ならNULLポインタ（アドレス0）として扱います

### weakシンボル

weakな定義は、同じ名前のstrongな定義が別にあれば、そちらが使われる定義です。reld_exampleの`weak_greet.c`には、`__attribute__((weak))`を付けて、`(default greeting)`と出力するだけの`greet`を書いてあります。

```console
$ reld -o weak1 start.o main.o weak_greet.o libgreet.a && ./weak1
(default greeting)
$ reld -o weak2 start.o main.o weak_greet.o greet.o libgreet.a && ./weak2
Hello, linker!
```

`greet.o`を加えると、strongな`greet`がweakな`greet`に勝ちます（reld_exampleでは`make weak`）。

glibcもこの仕組みを使っています。`libc.a`の`write`は、内部の関数`__libc_write`へのweakな別名です。プログラムが自分で`write`を定義しても多重定義のエラーにはならず、リンカはプログラム側の定義を使います。

### 定義のないweak参照

weakは参照にも付けられます。`main2.c`では、定義がなくてもよいフック関数をweakで宣言しています。

**main2.c**

```c
void greet(const char *name);
void exit_with(int code);
__attribute__((weak)) void on_exit_hook(void);

void run(void) {
    greet("linker");
    if (on_exit_hook) on_exit_hook();   // 定義がなければNULLポインタ
    exit_with(0);
}
```

```console
$ reld -o hook start.o main2.o greet.o libgreet.a --trace symbols
[symbols]
SYMBOL BINDING TYPE DEFINITION
__bss_start STB_GLOBAL STT_NOTYPE <script>
...
greet STB_GLOBAL STT_FUNC greet.o
on_exit_hook STB_WEAK STT_NOTYPE undefined weak -> 0
put STB_GLOBAL STT_FUNC libgreet.a(put.o)
...
$ ./hook
Hello, linker!
```

`--trace symbols`は、シンボルごとにどの定義を選んだかを表示します。`on_exit_hook`は定義がどこにもありませんが、weakな参照なのでエラーにならず、関数ポインタとしてはNULLポインタになります。リンカは、`on_exit_hook`のアドレスとして0を書き込みます。そのため`if (on_exit_hook)`が偽になり、呼び出しは飛ばされます（reld_exampleでは`make hook`）。なお、weakな参照は、ライブラリからオブジェクトファイルを取り込む理由にはなりません。

定義が`<script>`になっているのは、リンカスクリプトが定義したシンボルです（この資料の最後で扱います）。

### 多重定義と未定義のエラー

strongな定義が2つあると、どちらを使えばよいか決められません。逆に、strongな参照に対して定義が1つもなければ、アドレスを決めようがありません。

```console
$ reld -o multi start.o main.o greet.o greet.o libgreet.a
Error: multiple definition of symbol: greet in files: greet.o and greet.o
$ reld -o undef start.o main.o greet.o
Error: undefined symbol: exit_with in file: main.o
```

エラーの文面はリンカごとに違います。GNU ldでは``multiple definition of `greet'``と``undefined reference to `exit_with'``になります（reld_exampleでは`make multi`と`make undef`）。

### リンカスクリプトが定義するシンボル

ここまでは主に、オブジェクトファイルの中にあるシンボルの定義と参照を見てきました。リンカスクリプトもシンボルを定義できます。reldの既定のスクリプト（本文の「セクションの配置」で読みます）には、こういう行があります。

**既定のリンカスクリプト（抜粋）**

```
  _edata = .;
  PROVIDE(edata = .);
  __bss_start = .;
  ...
  _end = .;
  PROVIDE(end = .);
```

`_end = .;`のような普通の代入は、常に`_end`を定義します。`.`はその時点のアドレスを表すので、`_end`はデータの終わりのアドレスになります。`PROVIDE(end = .)`が`end`を定義するのは、`end`がどこかから参照されていて、しかもどの入力も`end`を定義していないときだけです。プログラムが自分で`end`という変数を作っても、多重定義にならないようにするための仕組みです。

`PROVIDE_HIDDEN`は同じ条件でシンボルを定義し、その可視性を`hidden`にします。同じ実行ファイルにリンクされるオブジェクトファイルからは参照できますが、実行ファイルの外には公開されません。本文の「glibcの静的リンク」に出てくる`__rela_iplt_start`などは、この形で定義されています。

もう1つ、**COMMONシンボル**（初期値のないグローバル変数を、複数のファイルで定義できる古い仕組み）があります。GNU ldはCOMMONシンボル同士を1つにまとめますが、reldは対応しておらず、エラーにしています。GCC 10以降は既定で`-fno-common`なので、普通にコンパイルしたコードでは出てきません。
