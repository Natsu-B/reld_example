# reldの記事の補足資料

坂井ゼミ合同誌の記事「自作リンカでglibcのprintfを静的リンクする」で、紙面の都合で本文から外した内容です。本文と同じく、実行例はUbuntu 24.04（GCC 13.3、GNU Binutils 2.42、glibc 2.39）で確かめました。

| 資料 | 内容 | 本文の対応する節 |
|---|---|---|
| [ELFの基礎とシンボル解決の細かい規則](elf-basics.md) | `readelf`の読み方、静的ライブラリからの取り出し方、weak、多重定義と未定義、リンカスクリプトが定義するシンボル | リンカは何をしているか、オブジェクトファイルを集める、シンボル解決 |
| [セクション配置の細かい規則](layout-details.md) | `.text`と`.rodata`、`.init`の中身、`.tbss`とロケーションカウンタ、複数の規則、孤児セクション、`DATA_SEGMENT_ALIGN`、`SIZEOF_HEADERS` | セクションの配置、glibcの静的リンク |
| [起動コードとスタックのアラインメント](startup-code.md) | `_start`をアセンブリで書く理由 | セクションの配置 |
| [再配置の計算コードと範囲チェック](relocation-details.md) | reldの計算コード、RIP相対、値が収まらない場合のreldとGNU ldの出力 | 再配置の適用 |
| [実行ファイルの書き出しとGNU ldとの比較](output-and-gnu-ld.md) | 書き出す内容、セクションヘッダとシンボル表、GNU ldとの比較 | おわりに |
| [ほかのリンカとの違い](other-linkers.md) | lldとmoldでの、ライブラリの順番、`--start-group`、索引のないアーカイブ、エラーの出し方 | オブジェクトファイルを集める、再配置の適用 |
| [PIEと動的リンク](pie-and-dynamic-linking.md) | PIE、動的再配置、動的リンカ、PLTと遅延バインディング | おわりに |
