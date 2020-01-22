include_guard(GLOBAL)

if(NOT MODULE_DIR)
  get_filename_component(moduledir "modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are located")
endif()

function (add_module directory)
  # NOT current binary dir
  get_filename_component(abs "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_DIR}")
  get_filename_component(listfile "CMakelists.txt" ABSOLUTE
	BASE_DIR "${abs}")
  file(TIMESTAMP "${listfile}" timestamp)
  if(timestamp)
	add_subdirectory("${abs}")
	return()
  endif(timestamp)
  set(options)
  set(onevalue FUNCTION)
  set(multivalue GIT)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  if(A_GIT)
	list(GET A_GIT 0 commit)
	list(SUBLIST A_GIT 1 -1 A_GIT)
	list(JOIN A_GIT " " A_GIT)	
	cmake_parse_arguments(GIT
	  "SHALLOW;NORECURSE" "" "URLS" ${A_GIT})
	if(GIT_SHALLOW)
	  set(GIT_SHALLOW "--depth=0")
	endif()
	if(GIT_NORECURSE)
	  set(GIT_NORECURSE "")
	else()
	  set(GIT_NORECURSE "--recurse-submodules")
	endif()

	foreach(url IN LISTS GIT_URLS)
	  execute_process(
		COMMAND git clone
		${GIT_SHALLOW}
		${GIT_RECURSE}
		-b "${commit}"
		"${url}" "${abs}"
		RESULT_VARIABLE result)
	  if(result EQUAL 0)
		file(TIMESTAMP "${listfile}" timestamp)
		if(timestamp)
		  add_subdirectory("${abs}")
		  return()
		endif(timestamp)
	  endif(result EQUAL 0)
	  message(WARNING "URL ${url} failed for GIT ${directory}")
	endforeach(url in LISTS urls)
	message(WARNING
	  "Could not clone ${directory} from any of its GIT URIs!")
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not clone ${directory} by any method!")
endfunction(add_module)
