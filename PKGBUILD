# Maintainer: nino-natsume <1093219307@qq.com>
# Contributor: nino-natsume <1093219307@qq.com>

pkgname=eri
pkgver=1.1.6
pkgrel=1
pkgdesc="绘里酱人格包：opencode 人格技能、personality 配置（default/绘里酱/erotic）、5 个子智慧体、mood 系统、18 种终端工具部署脚本与跨平台安装器"
arch=(any)
url="https://github.com/nino-natsume/eri"
license=(AGPL-3.0-or-later)
depends=(opencode nodejs npm)
optdepends=('bun: 可视化管理面板独立窗口运行时（全平台）'
            'webkit2gtk-4.1: Linux 下面板窗口的 WebView 运行时')
install=eri.install
source=(
  SKILL.md
  erotic-chan.md
  code-monkey.md
  debug-san.md
  architect-sama.md
  test-chan.md
  personality.json
  opencode.json
  package.json
  opencode-package.json
  opencode-package-lock.json
  LICENSE
  eri.md
  install-eri.sh
  ui/panel.js
  ui/page.js
  ui/webview.js
  ui/core.js
  ui/worker.js
  ui/ring.js
  ui/native/libwebview-x64.so
  ui/native/libwebview-arm64.so
)
sha256sums=(
  '08731ee6ee2c5857010d8131c8668b662ef4cb516af9e3ed9154c319e3b395f3'
  'e2503af58efaa1ad8897da4d3e7d029543e3f2577b8b96cd09a4e651fa26e8ff'
  '57f9b989beda84c21d8891fc8cb25432d6322f57d92f887df9609be8bce281eb'
  '01fd116f53f5927ebcf0fb36ac6bda2f32c9f49d95a5b2ef40d348bbde048c19'
  'fc7de41774829d3f555533ba6315e31543abffdf992aee3e8cbf29b11504125f'
  '2f0f2dbfcfa3bb03d334a2cc842fb34726776110bf0c8cf8dec5919a5f201faa'
  '0702714a367532e09e26a5b6399e4ff83ac89facb6bafbefe7f12b6ca1d72049'
  '99c846429371d52f83e510ed90ca86398549c1f08f7e2774c3d08b64e3142bec'
  '4f3e7cb7b8460aadbe6f8a6e8f35e4a75bfadbb8a5e87669b5516d21f1592f02'
  '3fd45c326b2f1aeb9bd311dacc250e355b21e35d0f8793b7f41a981941efdef4'
  '8aaead0bdcff4fda3451156aec41a27eb3d7efde94405e83e30a6b991dd2eb54'
  '0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0'
  '531e65723b98d3e8f8a6744b2175d2fb47f532de1d473d3351d866808f9676fb'
  '154199f26558b27c34a45bc83be604b986f82e8dbc015dfb49594207a7dfd1c9'
  '14c5ea01e8bed4f8519b7747077fa850eca50ce60716d4079618d48d130388eb'
  'be072cd34cb744ac5be5508b7ba0013c4531485b21222321d6b20d8c0928f33a'
  'dd31d36b5ef165f62e697e32b2e868e1c7fa4c0386588cf5767d40a8ec38eae0'
  '89ef28428ca2b6b2f5f0255e75eef51e0382b1ec17daf6a627dbb7dd5eed3f60'
  '3baabd95d21debaf2933663923be6a73d5bc605daad2f6da0a93df3466a87569'
  '036943972421a9a13b6b8a133fa7389c6ed6fe4af5a48035b490fb5eb2fab86c'
  '71b051644a6871c929a1fb4dac31fdbaaa3d7e52d62ee3d806a3321590105ded'
  '80aee08b776c2465fdbbb7d4ba2dcf77a6c5f6f6f6bf9eebae05450ca9bc73cd'
)

package() {
	local dest="$pkgdir/usr/share/eri"

	install -d "$dest/skill/eri" "$dest/agent"
	install -Dm644 "$srcdir/SKILL.md" "$dest/skill/eri/SKILL.md"
	install -m644 \
		"$srcdir/erotic-chan.md" \
		"$srcdir/code-monkey.md" \
		"$srcdir/debug-san.md" \
		"$srcdir/architect-sama.md" \
		"$srcdir/test-chan.md" \
		"$dest/agent/"
	install -m644 "$srcdir/personality.json" "$srcdir/opencode.json" "$srcdir/package.json" "$srcdir/opencode-package.json" "$srcdir/opencode-package-lock.json" "$dest/"
	install -m644 "$srcdir/eri.md" "$dest/eri.md"
	install -Dm755 "$srcdir/install-eri.sh" "$dest/install-eri.sh"
	install -Dm644 "$srcdir/ui/panel.js" "$dest/ui/panel.js"
	install -Dm644 "$srcdir/ui/page.js" "$dest/ui/page.js"
	install -Dm644 "$srcdir/ui/webview.js" "$dest/ui/webview.js"
	install -Dm644 "$srcdir/ui/core.js" "$dest/ui/core.js"
	install -Dm644 "$srcdir/ui/worker.js" "$dest/ui/worker.js"
	install -Dm644 "$srcdir/ui/ring.js" "$dest/ui/ring.js"
	install -Dm644 "$srcdir/ui/native/libwebview-x64.so" "$dest/ui/native/libwebview-x64.so"
	install -Dm644 "$srcdir/ui/native/libwebview-arm64.so" "$dest/ui/native/libwebview-arm64.so"
	install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
