# Maintainer: nino-natsume <1093219307@qq.com>
# Contributor: nino-natsume <1093219307@qq.com>

pkgname=eri
pkgver=1.1.0
pkgrel=1
pkgdesc="绘里酱人格包：opencode 人格技能、personality 配置（default/绘里酱/erotic）、5 个子智慧体、mood 系统、18 种终端工具部署脚本与跨平台安装器"
arch=(any)
url="https://github.com/nino-natsume/eri"
license=(MIT)
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
  LICENSE
  eri.md
  install-eri.sh
)
sha256sums=(
  '08731ee6ee2c5857010d8131c8668b662ef4cb516af9e3ed9154c319e3b395f3'
  'e2503af58efaa1ad8897da4d3e7d029543e3f2577b8b96cd09a4e651fa26e8ff'
  '57f9b989beda84c21d8891fc8cb25432d6322f57d92f887df9609be8bce281eb'
  '01fd116f53f5927ebcf0fb36ac6bda2f32c9f49d95a5b2ef40d348bbde048c19'
  'fc7de41774829d3f555533ba6315e31543abffdf992aee3e8cbf29b11504125f'
  '2f0f2dbfcfa3bb03d334a2cc842fb34726776110bf0c8cf8dec5919a5f201faa'
  '0702714a367532e09e26a5b6399e4ff83ac89facb6bafbefe7f12b6ca1d72049'
  '96aa102fdc56c94e5ebd990fce4d3ba7427528a3c90e4afd1f5ed094ababb316'
  'b9a3dfe7db31adfe8d263cd3b6a722a805703e037bad20441496a45d330144c4'
  'f0eef8be52e2207fc33200701aa1132780c20c8751546c27ea3637698d7c9b26'
  '531e65723b98d3e8f8a6744b2175d2fb47f532de1d473d3351d866808f9676fb'
  '2a6909a7eb7b36f658609bb19899ff5d3c969645d85b8dd075d5e44a7d9e044e'
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
	install -m644 "$srcdir/personality.json" "$srcdir/opencode.json" "$srcdir/package.json" "$dest/"
	install -m644 "$srcdir/eri.md" "$dest/eri.md"
	install -Dm755 "$srcdir/install-eri.sh" "$dest/install-eri.sh"
	install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
