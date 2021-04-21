cmake_minimum_required(VERSION 3.8.0)

if(NOT CMAKE_SCRIPT_MODE_FILE)
	message(STATUS "Usage: cmake -P cmake/Notarization.cmake")
endif()

function(FETCH_REGEX _output _regex _data)
	string(REGEX MATCH "${_regex}" _unused "${_data}")

	if(CMAKE_MATCH_1)
		string(STRIP "${CMAKE_MATCH_1}" output)
		set(${_output} ${output} PARENT_SCOPE)
	endif()
endfunction()

find_program(XCRUN xcrun)
if(NOT XCRUN)
	message(FATAL_ERROR "Cannot find 'xcrun'")
endif()

file(GLOB DMG_FILE *.dmg)
list(LENGTH DMG_FILE DMG_FILE_LEN)
if(NOT DMG_FILE_LEN EQUAL 1)
	message(FATAL_ERROR "Cannot determine *.dmg file: ${CMAKE_BINARY_DIR}")
endif()
message(STATUS "Using DMG: ${DMG_FILE}")

if(NOT USER)
	set(USER ausweisapp@governikus.de)
endif()

execute_process(COMMAND ${XCRUN} altool -t osx --notarize-app --verbose -u ${USER} -p @env:PASSWORD --primary-bundle-id com.governikus.ausweisapp2 -f ${DMG_FILE}
					OUTPUT_VARIABLE UUID_OUTPUT)

set(regex_uuid "RequestUUID = ([-|0-9|a-z]+)")
FETCH_REGEX(UUID "${regex_uuid}" "${UUID_OUTPUT}")
if(UUID)
	message(STATUS "Fetched UUID: ${UUID}")
else()
	message(FATAL_ERROR "Cannot fetch UUID: ${UUID_OUTPUT}")
endif()

set(regex_status "Status: ([a-z| ]+)")
while(TRUE)
	message(STATUS "Wait 30 seconds...")
	execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 30)

	execute_process(COMMAND ${XCRUN} altool -u ${USER} -p @env:PASSWORD --notarization-info ${UUID}
						OUTPUT_VARIABLE STATUS_OUTPUT)

	FETCH_REGEX(STATUS "${regex_status}" "${STATUS_OUTPUT}")

	if(STATUS STREQUAL "success")
		message(STATUS "Notarization succeeded...")
		break()
	elseif(STATUS STREQUAL "in progress")
		message(STATUS "Waiting...\n${STATUS_OUTPUT}")
	else()
		message(STATUS "Fetched Status: ${STATUS}")
		message(FATAL_ERROR "Notarization failed:\n${STATUS_OUTPUT}")
	endif()
endwhile()

execute_process(COMMAND ${XCRUN} stapler staple -v ${DMG_FILE})
execute_process(COMMAND ${XCRUN} stapler validate -v ${DMG_FILE})
