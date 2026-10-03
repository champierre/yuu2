# 「勇」の冒険 〜漢字錬成〜

登場するものがすべて漢字でできた、謎解きアクションゲームです。
[漢字謎解きアクション「勇」の冒険](https://github.com/champierre/yuu) を土台にしたリニューアル版です。

勇者「勇」は、字を拾って両手に持ち、**二つの字を合わせて新しい字を作り**ながら進みます。

- 父 ＋ 斤 ＝ **斧**　…… 大木を切り倒して、川に橋を架ける
- 日 ＋ 青 ＝ **晴**、山 ＋ 石 ＝ **岩** …… 字はこうして組み合わさってできている

どの字とどの字を合わせると何が生まれるかは、遊んでのお楽しみです。

## 遊び方

| 操作 | キーボード | スマホ |
|---|---|---|
| 歩く | ↑↓←→ / WASD | 上下左右 |
| 拾う・話す・調べる・使う | スペース（Z / Enter でも可） | 決 |
| 両手の字を合わせる（1 つだけなら置く） | X / C | 合 |
| 弓を引き絞る | スペース長押し → 離して射る | 決 長押し |
| 一時停止 | Esc / P | 止 |

ゲームパッドでも遊べます（A: 決める、X: 合わせる、Start: 一時停止）。
スマホを縦に持つと、上に遊びの画面、下に操作のボタンが並びます。横に持つと、ボタンは画面に重なって出て、画面が大きくなります。

## ステージ

| | 字 | 内容 |
|---|---|---|
| 其の一 | 斧 | 川の向こうへ。字の合わせ方を覚える |
| 其の二 | 鉄 | 門番は鉄を欲しがる。宝箱から出るのは金 |
| 其の三 | 蟲 | 矢をはね返す蟲との戦い |
| 其の四 | 灯 | 闇の洞窟。灯りをともして光の橋を渡る |
| 其の五 | 森 | 見張りの目をかいくぐって城へ忍び込む |
| 終の章 | 明 | 闇をまとった魔との戦い |

解き方はあえて書きません。字をよく見ると手がかりがあります。
ステージのあちこちに**隠れた合わせ方**があり、見つけた字は「字典」に載ります（全 10 字）。

## 動かす

Godot 4.7 以降が必要です。

```sh
godot --path .
```

### デバッグモード

好きなステージを自由に選んで試せるモードです。次のどれかで入ります。

- Godot エディタの ▶（F5）から起動する（自動で入る）
- `godot --path . -- debug=true`
- Web 版は URL の後ろに `?debug=true`（例: https://champierre.github.io/yuu2/?debug=true ）

デバッグモードでは:

- タイトルの「ステージを選ぶ」で、クリアしていないステージも選べる
- ステージの中で数字キー **1〜6** を押すと、そのステージへ飛ぶ
- **N** で、いまのステージをクリア扱いにする（次のステージへ進める）

画面の隅に赤い「デバッグ」の印が出ているときがデバッグモードです。

### Web 版

```sh
godot --headless --path . --export-release "Web" build/web/index.html
python3 tests/serve.py              # → http://localhost:8000
```

## テスト

```sh
./tests/run_all.sh
```

各ステージを**キーで歩いて通しで解く**テストがあります（`tests/test_stage*.gd`）。
画面の見た目を確かめたいときは、画面を PNG に写せます。

```sh
godot --path . --script tests/capture.gd -- res://scenes/stage1.tscn 2.0 /tmp/shot.png
```

## 作り

| ファイル | 役割 |
|---|---|
| `scripts/core/game.gd` | autoload `Game`。進み具合・字典の記録、場面の移り変わり、キーの割り当て |
| `scripts/core/sfx.gd` | autoload `Sfx`。効果音と BGM を、その場で合成して鳴らす（音の素材は無い） |
| `scripts/core/kanji.gd` | 字の合わせ方と、字典の説明 |
| `scripts/core/stage.gd` | ステージの土台。漢字で書いた地図を読む・拾う・合わせる・使う・弓・命・クリア |
| `scripts/core/glyph.gd` | 字 1 つ＝登場するもの 1 つ |
| `scripts/core/hero.gd` | 勇者。8 方向の移動と、両手の字 |
| `scripts/core/hud.gd` | 命・両手・案内・会話・合わせた字の札・一時停止 |
| `scripts/core/dark.gd` | 暗がりと明かり（シェーダー） |
| `scripts/core/shot.gd` / `walker.gd` / `enemy.gd` | 飛ぶもの・歩くもの・敵 |
| `scripts/core/fx.gd` | 演出の部品 |
| `scripts/core/touch_pad.gd` | スマホ用の画面のボタン |
| `scripts/stages/stage1.gd`〜`stage6.gd` | 各ステージ |
| `scripts/title.gd` / `ending.gd` | タイトル（ステージ選び・字典・遊び方）とエンディング |

ステージの地図は、スクリプトの中に漢字で書いてあります（`山` は山、`川` は川、`勇` が始まりの場所）。

## ライセンス

- 原作: [漢字謎解きアクション「勇」の冒険](https://scratch.mit.edu/projects/169268428/) /
  [その 2](https://scratch.mit.edu/projects/427402420/) by jishiha
- 同梱フォント `fonts/NotoSansJP-Regular.otf`: SIL Open Font License 1.1（[fonts/OFL.txt](fonts/OFL.txt)）
