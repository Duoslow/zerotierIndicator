# This is an example PKGBUILD file. Use this as a start to creating your own,
# and remove these comments. For more information, see 'man PKGBUILD'.
# NOTE: Please fill out the license field for your package! If it is unknown,
# then please put 'unknown'.

# Maintainer: Duoslow <heniugur@gmail.com>
pkgname=zerotierIndicator
pkgver=1.0
pkgrel=1
epoch=
pkgdesc="Displays Zerotier Network Members"
arch=(x86_64)
url="https://github.com/Duoslow/zerotierIndicator.git"
license=('GPL')
groups=()
depends=()
makedepends=(git)
checkdepends=()
optdepends=()
provides=(zerotierIndicator)
conflicts=(zerotierIndicator)
replaces=()
backup=()
options=()
install=
changelog=
source=("git+$url")
noextract=()
md5sums=('SKIP')
validpgpkeys=()

package() {
	cd zerotierIndicator
	chmod +x install.sh
	./install.sh
	printf "zerotier indicator installed add widget"
}
