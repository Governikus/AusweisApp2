# CPack
# http://www.cmake.org/Wiki/CMake:CPackConfiguration

set(PACKAGE_VERSION ${PROJECT_VERSION})

if(ANDROID AND NOT INTEGRATED_SDK)
	set(PACKAGE_VERSION ${PACKAGE_VERSION}-${CMAKE_ANDROID_ARCH_ABI})
endif()

if(DEFINED dvcs_distance)
	set(PACKAGE_VERSION ${PACKAGE_VERSION}+${dvcs_distance})
endif()

if(DEFINED dvcs_branch)
	set(PACKAGE_VERSION ${PACKAGE_VERSION}-${dvcs_branch})
endif()

if(DEFINED dvcs_phase)
	set(PACKAGE_VERSION ${PACKAGE_VERSION}-${dvcs_phase})
endif()

if(DEFINED dvcs_revision)
	set(PACKAGE_VERSION ${PACKAGE_VERSION}-${dvcs_revision})
endif()

if(ANDROID AND INTEGRATED_SDK)
	string(TOLOWER "${PROJECT_NAME}-" AAR_PROJECT_NAME)
	string(REGEX REPLACE "[0-9]*-" "-" AAR_PROJECT_NAME "${AAR_PROJECT_NAME}")
	set(FILENAME ${AAR_PROJECT_NAME}${PACKAGE_VERSION})
else()
	set(FILENAME ${PROJECT_NAME}-${PACKAGE_VERSION})
endif()

set(CPACK_PACKAGE_NAME ${PROJECT_NAME})
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_PACKAGE_VERSION_TWEAK ${PROJECT_VERSION_TWEAK})
set(CPACK_PACKAGE_VENDOR "Governikus GmbH & Co. KG")
set(CPACK_PACKAGE_CONTACT "info@governikus.de")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Governikus AusweisApp2")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${PROJECT_SOURCE_DIR}/README.rst")
set(CPACK_PACKAGE_FILE_NAME ${FILENAME})
set(CPACK_PACKAGE_INSTALL_DIRECTORY ${PROJECT_NAME})
set(CPACK_RESOURCE_FILE_LICENSE "${LICENSE_FILE}")


find_program(CONV uconv)
if(NOT CONV)
	find_program(CONV iconv)
endif()
find_program(ENSCRIPT enscript)
find_program(GS gs)

if(CONV AND ENSCRIPT AND GS)
	set(LICENSE_FILE ${FILENAME}-Lizenz.pdf)

	set(CONV_CMD ${CONV} -f utf-8 -t iso-8859-1 --output license.tmpfile.conv ${CPACK_RESOURCE_FILE_LICENSE})
	set(ENSCRIPT_CMD ${ENSCRIPT} -q -X 88591 -B --word-wrap -t ${PROJECT_NAME} --output license.tmpfile.ps license.tmpfile.conv)
	set(GS_CMD ${GS} -q -sPAPERSIZE=a4 -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=${LICENSE_FILE} license.tmpfile.ps)

	add_custom_command(OUTPUT ${LICENSE_FILE} COMMAND ${CONV_CMD} COMMAND ${ENSCRIPT_CMD} COMMAND ${GS_CMD})
	add_custom_target(license DEPENDS ${LICENSE_FILE})
endif()

if(APPLE AND NOT IOS)
	if(NOT CONV)
		message(FATAL_ERROR "Cannot find 'iconv' to convert LICENSE.txt")
	endif()

	execute_process(COMMAND ${CONV} -f UTF-8 -t MAC ${CPACK_RESOURCE_FILE_LICENSE} OUTPUT_FILE "${PROJECT_BINARY_DIR}/LICENSE.txt")
	set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_BINARY_DIR}/LICENSE.txt")
endif()

if(NOT CMAKE_BUILD_TYPE STREQUAL "DEBUG" AND NOT CMAKE_BUILD_TYPE STREQUAL "RELWITHDEBINFO")
	set(CPACK_STRIP_FILES TRUE)
endif()

set(CPACK_SOURCE_GENERATOR TGZ)
set(CPACK_SOURCE_PACKAGE_FILE_NAME ${FILENAME} CACHE INTERNAL "tarball basename")

set(CPACK_SOURCE_IGNORE_FILES "\\\\.hgignore" "\\\\.hgtags" "/\\\\.hg/" "\\\\.hgchurn")
list(APPEND CPACK_SOURCE_IGNORE_FILES "\\\\.gitignore" "/\\\\.git/")
list(APPEND CPACK_SOURCE_IGNORE_FILES "vendor.txt")
list(APPEND CPACK_SOURCE_IGNORE_FILES "${CMAKE_CURRENT_BINARY_DIR}")
list(APPEND CPACK_SOURCE_IGNORE_FILES "CMakeCache.txt")
list(APPEND CPACK_SOURCE_IGNORE_FILES "CMakeFiles")
list(APPEND CPACK_SOURCE_IGNORE_FILES "CMakeLists\\\\.txt\\\\.user")
list(APPEND CPACK_SOURCE_IGNORE_FILES "\\\\.project")
list(APPEND CPACK_SOURCE_IGNORE_FILES "\\\\.cproject")
list(APPEND CPACK_SOURCE_IGNORE_FILES "\\\\.reviewboardrc")
list(APPEND CPACK_SOURCE_IGNORE_FILES "utils")

set(CPACK_MONOLITHIC_INSTALL true)


if(WIN32)
	set(CPACK_GENERATOR WIX)
	set(CPACK_WIX_UPGRADE_GUID 4EE0E467-EAB7-483E-AB45-87BD1DB6B037)
	set(CPACK_WIX_PRODUCT_ICON ${RESOURCES_DIR}/images/desktop/npa.ico)
	set(CPACK_WIX_CULTURES de-DE en-US)
	# disable above line, enable beneath line to build MSI for english
	# set(CPACK_WIX_CULTURES en-US)
	set(CPACK_WIX_TEMPLATE ${PACKAGING_DIR}/win/WIX.template.in)
	set(CPACK_WIX_EXTRA_SOURCES ${PACKAGING_DIR}/win/install_settings.wxs ${PACKAGING_DIR}/win/runtime_settings.wxs ${PACKAGING_DIR}/win/gui.wxs)
	set(CPACK_WIX_UI_BANNER ${RESOURCES_DIR}/images/wix_banner.jpg)
	set(CPACK_WIX_UI_DIALOG ${RESOURCES_DIR}/images/wix_dialog.jpg)
	set(CPACK_WIX_EXTENSIONS WixUtilExtension WixFirewallExtension)
	set(CPACK_WIX_LIGHT_EXTRA_FLAGS -loc ${PACKAGING_DIR}/win/WIX.Texts.de-DE.wxl -loc ${PACKAGING_DIR}/win/WIX.Texts.en-US.wxl)
	# suppress warning LGHT1076/ICE61 caused by AllowSameVersionUpgrades
	set(CPACK_WIX_LIGHT_EXTRA_FLAGS -sw1076 ${CPACK_WIX_LIGHT_EXTRA_FLAGS})

	if(SIGNTOOL_CMD)
		message(STATUS "MSI can be signed with 'make package.sign'")
		set(MSI ${PROJECT_BINARY_DIR}/${CPACK_PACKAGE_FILE_NAME}.msi)
		add_custom_target(package.sign COMMAND ${SIGNTOOL_CMD} ${SIGNTOOL_PARAMS} ${MSI}
										COMMAND ${SIGNTOOL_CMD} verify /v /pa ${MSI})
	endif()

elseif(IOS)
	configure_file("${CMAKE_DIR}/Bundles.cmake.in" "${CMAKE_BINARY_DIR}/Bundles.cmake" @ONLY)
	if(INTEGRATED_SDK)
		set(Bundle_Target zip)
	else()
		set(Bundle_Target ipa)
	endif()
	add_custom_target(${Bundle_Target} COMMAND ${CMAKE_COMMAND} -DINTEGRATED_SDK=${INTEGRATED_SDK} -DCONFIG=$<CONFIGURATION> -P ${CMAKE_BINARY_DIR}/Bundles.cmake)

elseif(APPLE)
	set(CPACK_GENERATOR External DragNDrop)

	set(CPACK_EXTERNAL_ENABLE_STAGING ON)
	set(CPACK_EXTERNAL_PACKAGE_SCRIPT ${CMAKE_DIR}/macOS.pkg.cmake)

	set(MACOS_PACKAGING_DIR ${PACKAGING_DIR}/macos)
	set(CPACK_DMG_VOLUME_NAME ${CPACK_PACKAGE_NAME})
	set(CPACK_DMG_FORMAT UDBZ)
	set(CPACK_DMG_BACKGROUND_IMAGE ${RESOURCES_DIR}/images/macos/dmg_background.png)
	set(CPACK_DMG_SLA_DIR ${MACOS_PACKAGING_DIR}/sla)
	set(CPACK_DMG_SLA_LANGUAGES English German)

	# We can not generate the DS_STORE on each build since jenkins runs headless
	#set(CPACK_DMG_DS_STORE_SETUP_SCRIPT ${MACOS_PACKAGING_DIR}/prepare-ds_store.applescript)
	set(CPACK_DMG_DS_STORE ${MACOS_PACKAGING_DIR}/DS_Store)

elseif(ANDROID)
	find_program(androiddeployqt androiddeployqt CMAKE_FIND_ROOT_PATH_BOTH)
	if(NOT androiddeployqt)
		message(FATAL_ERROR "Cannot find androiddeployqt to create APKs")
	endif()
	message(STATUS "Using androiddeployqt: ${androiddeployqt}")

	file(READ "${QT_HOST_PREFIX}/src/android/templates/build.gradle" BUILD_GRADLE)

	if(INTEGRATED_SDK)
		string(REPLACE "apply plugin: 'com.android.application'" "apply plugin: 'com.android.library'" BUILD_GRADLE "${BUILD_GRADLE}")
	endif()

	file(WRITE "${CMAKE_INSTALL_PREFIX}/build.gradle" "${BUILD_GRADLE}")
	file(READ "${PACKAGING_DIR}/android/build.gradle.append" BUILD_GRADLE)
	file(APPEND "${CMAKE_INSTALL_PREFIX}/build.gradle" "${BUILD_GRADLE}")

	if(NOT INTEGRATED_SDK)
		file(APPEND "${CMAKE_INSTALL_PREFIX}/build.gradle" "android.defaultConfig.applicationId '${BUNDLE_IDENTIFIER}'\n")

		if(BUILD_PREVIEW)
			file(APPEND "${CMAKE_INSTALL_PREFIX}/build.gradle" "android.defaultConfig.applicationIdSuffix '.dev'\n")
		endif()
	endif()

	option(ANDROID_LINT "Lint Android package" ON)
	if(NOT ANDROID_LINT)
		file(APPEND "${CMAKE_INSTALL_PREFIX}/build.gradle" "tasks.lint.enabled = false\n")
	endif()

	if(INTEGRATED_SDK)
		set(ANDROID_FILE_EXT aar)
		file(APPEND "${CMAKE_INSTALL_PREFIX}/build.gradle" "android.defaultConfig.consumerProguardFiles 'consumer-rules.pro'\n")
		if(DEFINED dvcs_revision)
			set(POM_SNAPSHOT "-SNAPSHOT")
		endif()
		configure_file(${PACKAGING_DIR}/android/pom.xml.in ${CMAKE_INSTALL_PREFIX}/${CPACK_PACKAGE_FILE_NAME}.pom @ONLY)
		configure_file("${PACKAGING_DIR}/android/lint.aar.xml" "${CMAKE_INSTALL_PREFIX}/lint.xml" COPYONLY)
		configure_file("${PACKAGING_DIR}/android/consumer-rules.pro" "${CMAKE_INSTALL_PREFIX}/consumer-rules.pro" COPYONLY)
	else()
		set(ANDROID_FILE_EXT apk)
		configure_file("${PACKAGING_DIR}/android/lint.apk.xml" "${CMAKE_INSTALL_PREFIX}/lint.xml" COPYONLY)
	endif()
	message(STATUS "Prepare ${ANDROID_FILE_EXT} file generation")

	if(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
		set(ANDROID_FILE dist-debug.${ANDROID_FILE_EXT})
	else()
		set(DEPLOY_CMD_SIGN --release)

		if(INTEGRATED_SDK)
			set(ANDROID_FILE dist-release.aar)
		elseif(APK_SIGN_KEYSTORE AND APK_SIGN_KEYSTORE_ALIAS AND APK_SIGN_KEYSTORE_PSW)
			message(STATUS "Release build will be signed using: ${APK_SIGN_KEYSTORE} | Alias: ${APK_SIGN_KEYSTORE_ALIAS}")
			set(DEPLOY_CMD_SIGN --sign ${APK_SIGN_KEYSTORE} ${APK_SIGN_KEYSTORE_ALIAS} --storepass ${APK_SIGN_KEYSTORE_PSW} --digestalg SHA-256 --sigalg SHA256WithRSA)
			set(ANDROID_FILE dist-release-signed.apk)
		else()
			set(ANDROID_FILE dist-release-unsigned.apk)
			message(WARNING "Cannot sign release build! Set APK_SIGN_KEYSTORE, APK_SIGN_KEYSTORE_ALIAS and APK_SIGN_KEYSTORE_PSW!")
		endif()
	endif()

	set(DEPLOY_CMD ${androiddeployqt} --verbose --gradle --input ${ANDROID_DEPLOYMENT_SETTINGS} --output ${CMAKE_INSTALL_PREFIX} ${DEPLOY_CMD_SIGN})
	set(SOURCE_ANDROID_FILE ${CMAKE_INSTALL_PREFIX}/build/outputs/${ANDROID_FILE_EXT})

	if(NOT INTEGRATED_SDK)
		if(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
			set(SOURCE_ANDROID_FILE ${SOURCE_ANDROID_FILE}/debug)
		else()
			set(SOURCE_ANDROID_FILE ${SOURCE_ANDROID_FILE}/release)
		endif()
	endif()

	set(SOURCE_ANDROID_FILE ${SOURCE_ANDROID_FILE}/${ANDROID_FILE})

	set(DESTINATION_ANDROID_FILE ${CMAKE_INSTALL_PREFIX}/${CPACK_PACKAGE_FILE_NAME}.${ANDROID_FILE_EXT})
	# Add DEPENDS install someday
	# https://gitlab.kitware.com/cmake/cmake/issues/8438
	add_custom_target(${ANDROID_FILE_EXT}
				COMMAND ${DEPLOY_CMD}
				COMMAND ${CMAKE_COMMAND} -E copy ${SOURCE_ANDROID_FILE} ${DESTINATION_ANDROID_FILE}
				USES_TERMINAL)

	add_custom_command(TARGET ${ANDROID_FILE_EXT} POST_BUILD
				COMMAND ${CMAKE_INSTALL_PREFIX}/gradlew sourcesJar lint
				COMMAND ${CMAKE_COMMAND} -E copy build/libs/dist-sources.jar ${CPACK_PACKAGE_FILE_NAME}-sources.jar
				WORKING_DIRECTORY ${CMAKE_INSTALL_PREFIX})

	if(NOT INTEGRATED_SDK)
		find_program(apksigner apksigner HINTS ${ANDROID_SDK}/build-tools/${ANDROID_BUILD_TOOLS_REVISION} CMAKE_FIND_ROOT_PATH_BOTH)
		if(apksigner)
			add_custom_target(verify.signature COMMAND ${apksigner} verify --verbose --print-certs -Werr ${DESTINATION_ANDROID_FILE})
		endif()
	endif()

elseif(UNIX)
	set(CPACK_GENERATOR STGZ)
endif()


include(CPack)
