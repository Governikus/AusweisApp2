import common.Build
import static common.Constants.strip

def j = new Build
	(
		name: 'MacOS_Integrated',
		libraries: ['MacOS'],
		label: 'MacOS',
		xunit: true
	).generate(this)


j.with
{
	steps
	{
		shell('security unlock-keychain ${KEYCHAIN_CREDENTIALS} ${HOME}/Library/Keychains/login.keychain-db')

		shell(strip('''\
			cd build;
			cmake ../source
			-DCMAKE_PREFIX_PATH=${WORKSPACE}/libs/build/dist
			-DCMAKE_CXX_COMPILER_LAUNCHER=ccache
			-DINTEGRATED_SDK=ON
			-DSANITIZER=on
			'''))

		shell('''\
			export DYLD_FRAMEWORK_PATH=${WORKSPACE}/libs/build/dist/lib
			export DYLD_LIBRARY_PATH=${WORKSPACE}/libs/build/dist/lib
			cd build; make ${MAKE_FLAGS}
			'''.stripIndent().trim())

		shell('''\
			export DYLD_FRAMEWORK_PATH=${WORKSPACE}/libs/build/dist/lib
			export DYLD_LIBRARY_PATH=${WORKSPACE}/libs/build/dist/lib
			export QT_PLUGIN_PATH=${WORKSPACE}/libs/build/dist/plugins
			cd build; ctest --output-on-failure ${MAKE_FLAGS}
			'''.stripIndent().trim())
	}
}
