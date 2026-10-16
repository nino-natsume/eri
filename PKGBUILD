# Maintainer: nino-natsume <1093219307@qq.com>
# Contributor: nino-natsume <1093219307@qq.com>

pkgname=eri
pkgver=1.1.4
pkgrel=1
pkgdesc="绘里酱人格包：opencode 人格技能、personality 配置（default/绘里酱/erotic）、5 个子智慧体、mood 系统、18 种终端工具部署脚本与跨平台安装器"
arch=(any)
url="https://github.com/nino-natsume/eri"
license=(AGPL-3.0-or-later)
depends=(opencode nodejs npm)
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
  '6bac6ee3f93fb71d42c674d76976730cac5f1a2ee96b9d5a8d9cc9d9d396814c'
  '3fd45c326b2f1aeb9bd311dacc250e355b21e35d0f8793b7f41a981941efdef4'
  '8aaead0bdcff4fda3451156aec41a27eb3d7efde94405e83e30a6b991dd2eb54'
  '0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0'
  '531e65723b98d3e8f8a6744b2175d2fb47f532de1d473d3351d866808f9676fb'
  '154199f26558b27c34a45bc83be604b986f82e8dbc015dfb49594207a7dfd1c9'
  'e2723c5c6e135aa17fa77d3577ee3515abb2be2676be278ad26e27352fb1b302'
  '3f4105cb1cf0586e0fba151d26c92702fcbb84a64c46d9daaa59f45bd6480924'
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
	install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
