import common.Build
import static common.Constants.strip

def j = new Build
	(
		name: 'iOS_Simulator_Framework',
		libraries: ['iOS_Simulator'],
		label: 'iOS',
		artifacts: 'build/*.zip,build/*.bcsymbolmap'
	).generate(this)


j.with
{
	steps
	{
		shell('security unlock-keychain ${KEYCHAIN_CREDENTIALS} ${HOME}/Library/Keychains/login.keychain-db')

		shell(strip('''\
			cd build;
			cmake ../source
			-DCMAKE_BUILD_TYPE=MinSizeRel
			-DCMAKE_PREFIX_PATH=\${WORKSPACE}/libs/build/dist
			-DCMAKE_TOOLCHAIN_FILE=../source/cmake/iOS.toolchain.cmake
			-DINTEGRATED_SDK=ON
			-DCMAKE_OSX_SYSROOT=iphonesimulator
			-DCMAKE_OSX_ARCHITECTURES=x86_64
			-GXcode
			'''))

		shell('cd build; xcodebuild -configuration MinSizeRel')
		shell('cd build; xcodebuild -configuration MinSizeRel -target zip')
	}
}
