# 再配置の計算コードと範囲チェック

本文の「再配置の適用」を補う資料です。例はreld_exampleの[`nolibc`](../nolibc)ディレクトリのもので、`make`で入力のオブジェクトファイルを作れます。

## reldの計算コード

再配置の値は、シンボルのアドレス`S`、補正値`A`、書き換える位置のアドレス`P`から、種類ごとに決まった式で計算します。

| 種類 | 式 | 幅 |
|---|---|---|
| `R_X86_64_64` | `S + A` | 64ビット |
| `R_X86_64_32` | `S + A` | 32ビット（符号なし） |
| `R_X86_64_32S` | `S + A` | 32ビット（符号付き） |
| `R_X86_64_PC32`、`R_X86_64_PLT32` | `S + A - P` | 32ビット（符号付き） |

reldのコードも、この表をそのまま写したような形をしています。

**src/relocate/x86_64.rs（抜粋）**

```rust
let s = i128::from(operands.iplt_address.unwrap_or(operands.symbol));
let a = i128::from(operands.addend);
let p = i128::from(operands.place);
let (width, signedness, value) = match ty {
    R64 => (Bits64, Either, s + a),
    R32 => (Bits32, Unsigned, s + a),
    R32S => (Bits32, Signed, s + a),
    Pc32 | Plt32 => (Bits32, Signed, s + a - p),
    // GOT や TLS 用の種類は「glibcの静的リンク」で
    ...
};
```

計算に`i128`（128ビット整数）を使っているのは、計算の途中で値があふれて折り返し、後の範囲チェックをすり抜けてしまうのを防ぐためです。1行目の`iplt_address`は、本文の「glibcの静的リンク」のIFUNCで説明しています。

> **RIP相対**
>
> `0x10(%rip)`のような書き方は**RIP相対**と呼ばれ、「次の命令の先頭から0x10バイト先」を意味します（`%rip`は次に実行する命令のアドレスを持つレジスタです）。x86-64のコードは、このRIP相対で変数や関数を指すことが多く、それが`R_X86_64_PC32`などの再配置になります。本文の「glibcの静的リンク」に出てくる`jmp *0xab652(%rip)`も、RIP相対の書き方です。

## 値が書き込む幅に収まらない場合

書き換える幅は32ビットのことが多く、計算した値が収まらない場合もあります。試しに、`.rodata`を置く前に`. = 0x100000000;`と書いて、文字列を4GiB（`0x100000000`）以上のアドレスに置くリンカスクリプト`far.ld`でリンクしてみます（reld_exampleにあります）。

```console
$ reld -T far.ld -o far start.o main.o greet.o libgreet.a
Error: relocation R32 for symbol '' at 0x401010 overflows Unsigned Bits32 field: value 0x100000000
```

`mov $0x0,%edi`の書き換え（`R_X86_64_32`）で、32ビットに収まらないアドレス`0x100000000`を書き込もうとして止まりました（reld_exampleでは`make far`）。シンボル名が空なのは、文字列をセクションのシンボル経由で参照しているためです。リンカは書き込む前に範囲を確かめ、収まらなければエラーにして、実行ファイルを作りません。黙って下位32ビットだけを書くと、まったく違うアドレスを指す実行ファイルができてしまうからです。

ただし、エラーの出し方はreldとGNU ldで違います。同じ入力をGNU ldでリンクすると、次のようになります。

```console
$ ld -T far.ld -o far start.o main.o greet.o libgreet.a
main.o: in function `run':
main.c:(.text+0x5): relocation truncated to fit: R_X86_64_32 against `.rodata.str1.1'
greet.o: in function `greet':
greet.c:(.text+0x12): relocation truncated to fit: R_X86_64_32 against `.rodata.str1.1'
greet.c:(.text+0x3d): relocation truncated to fit: R_X86_64_32 against `.rodata.str1.1'
```

reldは最初に見つけた1か所でエラーにしますが、GNU ldは再配置を最後まで処理して、収まらない3か所をすべて表示します。GNU ldは、場所を`main.c:(.text+0x5)`のように入力ファイルの中の位置で、参照先をセクション名`.rodata.str1.1`で示すので、こちらのほうがどこを直せばよいかわかりやすくなっています。lldもGNU ldと同じように、収まらない箇所を続けて表示します。moldが読めるリンカスクリプトは一部の命令だけなので、`far.ld`は読み込む段階でエラーになります。

`R_X86_64_32`と`R_X86_64_32S`は、同じ32ビットでも範囲が違います。前者は0から`0xffffffff`まで、後者は下位32ビットを符号拡張して元に戻せる範囲（`0xffffffff80000000`以上か、`0x7fffffff`以下）です。CPUが32ビットの値を64ビットに広げるとき、命令によって「0で埋める」か「符号で埋める」かが違うためです。
