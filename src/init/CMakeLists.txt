#####################################################################
# The module init is responsible to bootstrap the appplication.
#####################################################################

ADD_PLATFORM_LIBRARY(AusweisAppInit)

target_link_libraries(AusweisAppInit ${Qt}::Core OpenSSL::Crypto AusweisAppGlobal AusweisAppCore)

if(NOT INTEGRATED_SDK)
	target_link_libraries(AusweisAppInit ${Qt}::Gui) # QGuiApplication
	if(DESKTOP)
		target_link_libraries(AusweisAppInit ${Qt}::Widgets) # QApplication
	endif()
endif()


function(CONFIGURE_CONFIG_H)
	if(VENDOR_GOVERNIKUS)
		set(VENDOR_DOMAIN governikus.de)
	else()
		set(VENDOR_DOMAIN)
	endif()

	if(VERSION_DVCS)
		set(VERSION ${VERSION_DVCS})
	else()
		set(VERSION ${PROJECT_VERSION})
	endif()

	set(PRODUCT ${PROJECT_NAME})

	configure_file(config.h.in config.h @ONLY)
endfunction()

CONFIGURE_CONFIG_H()
