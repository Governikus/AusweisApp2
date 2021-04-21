import common.Release
import static common.Constants.strip

def j = new Release
	(
		name: 'MacOS_DMG_PKG',
		libraries: ['MacOS'],
		label: 'MacOS',
		artifacts: 'libs/build/Toolchain_*,build/*.dmg,build/*.pkg'
	).generate(this)


j.with
{
	steps
	{
		shell('security unlock-keychain ${KEYCHAIN_CREDENTIALS} ${HOME}/Library/Keychains/login.keychain-db')

		shell(strip("""\
			cd build;
			cmake ../source
			-DCMAKE_PREFIX_PATH=\${WORKSPACE}/libs/build/dist
			-DCMAKE_CXX_COMPILER_LAUNCHER=ccache
			-DCMAKE_BUILD_TYPE=MinSizeRel
			"""))

		shell('''\
			export DYLD_FRAMEWORK_PATH=${WORKSPACE}/libs/build/dist/lib
			export DYLD_LIBRARY_PATH=${WORKSPACE}/libs/build/dist/lib
			cd build; make ${MAKE_FLAGS} package
			'''.stripIndent().trim())

		shell('cd build/_CPack_Packages/Darwin/; codesign -vvvv **/**/*.app')
		shell('cd build/_CPack_Packages/Darwin/DragNDrop; spctl -a -vv **/*.app')

		shell('cd build/; cmake -P ../source/cmake/Notarization.cmake')

		shell('cd build/; xcrun altool -t osx --upload-app -u "ausweisapp@governikus.de" -p @env:PASSWORD -f *.pkg')
	}
}
