import common.LibraryReview

def j = new LibraryReview
	(
		name: 'iOS_Simulator',
		label: 'iOS'
	).generate(this)


j.with
{
	steps
	{
		shell('cd source; cmake -DCMD=IMPORT_PATCH -P cmake/cmd.cmake')

		shell('security unlock-keychain \${KEYCHAIN_CREDENTIALS} \${HOME}/Library/Keychains/login.keychain-db')

		shell("cd build; cmake ../source/libs -DCMAKE_BUILD_TYPE=release -DCMAKE_TOOLCHAIN_FILE=../source/cmake/iOS.toolchain.cmake -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_OSX_ARCHITECTURES=x86_64 -DPACKAGES_DIR=\${PACKAGES_DIR}")

		shell('cd build; make compress')
	}
}
