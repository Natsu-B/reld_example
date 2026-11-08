# reldのexample repoです
2026年11月の技術書典で配布した、25年度坂井ゼミ合同誌に掲載した、reldの解説記事用のexampleリポジトリです。

# How To Start
```bash
git clone https://github.com/Natsu-B/reld_example.git --recursive
./init.sh
```

`./init.sh` で reld をビルドしたあと、各ディレクトリで `make` を実行します。
記事の実行例は Ubuntu 24.04（GCC 13.3、GNU Binutils 2.42、glibc 2.39）で確かめました。
`nix develop` でも動きますが、GCC や glibc の版が違うので、アドレスなどの数値は記事と変わります。

# 補足資料

記事で紙面の都合により省いた内容は、[`doc/`](doc/README.md)にまとめています。

# ディレクトリ

## nolibc：標準ライブラリを使わない小さな例

| コマンド | 内容 |
|---|---|
| `make run` | `hello` をリンクして実行する |
| `make trace TRACE=archive` | `--trace` で各段階の結果を表示する（`inputs`、`archive`、`symbols`、`mapping`、`got`、`layout`、`relocations`） |
| `make map` | リンクマップを `hello.map` に書き出す |
| `make order` | ライブラリを先に書いて undefined symbol を起こす（`make order LD=ld.lld` なら lld でリンクでき、成功する） |
| `make weak` | weak な `greet` と strong な `greet` |
| `make hook` | 定義のない weak 参照が 0 になる |
| `make multi` / `make undef` | multiple definition と undefined symbol のエラー |
| `make far` | 文字列を 4GiB より上に置いて、再配置の範囲検査に引っかける |

`order`、`multi`、`undef`、`far` は、エラーになるのが正しい結果です。

## glibc：glibc を静的リンクする例

| コマンド | 内容 |
|---|---|
| `make run` | `hello_glibc.c` を reld で静的リンクして実行する |
| `make trace TRACE=got` | GOT、IPLT スタブ、IRELATIVE を表示する |
| `make compare` | 同じ入力を GNU ld でもリンクし、実行結果、ファイルの大きさ、IRELATIVE の数を比べる |

reld は `-L` と `-l` に対応していないので、`Makefile` が gcc に `crt1.o` や `libc.a` の場所を聞いて、フルパスで渡しています。
