if(ENV{__ADD_MODULE_INCLUDED__})
  return()
endif()

if(NOT MODULE_DIR)
  get_filename_component(moduledir "modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are located")
  get_filename_component(moduledir "module_bin" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_BIN_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are compiled")
endif(NOT MODULE_DIR)

function (safely_add_subdir source binary)
  get_property(subdirs DIRECTORY "${CMAKE_SOURCE_DIR}"
	PROPERTY SUBDIRECTORIES)
  list(FIND subdirs "${source}" foundit)
  if(foundit EQUAL -1)
	add_subdirectory("${source}" "${binary}")
  else(foundit EQUAL -1)
	#message("ALREADY ADDED ${source}")
  endif(foundit EQUAL -1)
endfunction(safely_add_subdir)

function (add_module_git directory source listfile RESULT commit)
  get_property(prop GLOBAL PROPERTY "add_module_git_${source}" DEFINED)
  if(prop)
	return()
  endif()
  define_property(GLOBAL PROPERTY "add_module_git_${source}"
	BRIEF_DOCS ""
	FULL_DOCS "")
  cmake_parse_arguments(PARSE_ARGV 5 GIT
	"NOSHALLOW;RECURSE" "" "")
  get_filename_component(dotgit ".git" ABSOLUTE
	BASE_DIR "${source}")
  file(TIMESTAMP "${dotgit}" dotgit)
  if(dotgit)
	# already there yo
	set(temp "${source}")
  else(dotgit)
	get_filename_component(temp "temp" ABSOLUTE
	  BASE_DIR "${MODULE_DIR}")
	file(REMOVE_RECURSE "${temp}")
  endif(dotgit)

  if(NOT GIT_RECURSE)
	set(GIT_RECURSE "")
  else()
	set(GIT_RECURSE "--recurse-submodules")
  endif()

  macro (git)
	execute_process(
	  COMMAND git ${ARGV}
	  WORKING_DIRECTORY "${temp}"
	  RESULT_VARIABLE result)
  endmacro(git)
  if(NOT dotgit)
	file(MAKE_DIRECTORY "${temp}")
	git(init)
	git(config --replace-all advice.detachedHead false)
	git(remote add origin placeholder)
	if(NOT result EQUAL 0)
	  message(FATAL_ERROR "Couldn't init a git repository? ${herp} ${result}")
	endif()
  endif(NOT dotgit)
  foreach(url IN LISTS GIT_UNPARSED_ARGUMENTS)
	git(remote set-url origin "${url}")
	if(NOT GIT_NOSHALLOW)
	  # https://stackoverflow.com/questions/31278902/how-to-shallow-clone-a-specific-commit-with-depth-1
	  if(result EQUAL 0)
		git(fetch ${GIT_RECURSE} --depth 1 origin "${commit}")
		if(result EQUAL 0)
		  git(checkout FETCH_HEAD)
		endif()
	  endif()
	else(NOT GIT_NOSHALLOW)
	  git(pull ${GIT_RECURSE} origin "${commit}")
	endif(NOT GIT_NOSHALLOW)
	if(result EQUAL 0)
	  git(checkout "${commit}")
	  if(NOT result EQUAL 0)
		message(FATAL_ERROR "Could not checkout commit ${commit} from ${directory}")
	  endif()
	  if(NOT dotgit)
		file(RENAME "${temp}" "${source}")
		file(REMOVE_RECURSE "${temp}")
	  endif(NOT dotgit)
	  set("${RESULT}" TRUE PARENT_SCOPE)
	  return()
	endif(result EQUAL 0)
	message(WARNING "URL ${url} failed for GIT ${directory}")
  endforeach(url in LISTS GIT_UNPARSED_ARGUMENTS)
  message(WARNING
	"Could not clone ${directory} from any of its GIT URIs!")
  set("${RESULT}" FALSE PARENT_SCOPE)
  if(NOT dotgit)
	file(REMOVE_RECURSE "${temp}")
  endif(NOT dotgit)
endfunction(add_module_git)

function (add_module directory)
  # NOT current binary dir
  get_filename_component(source "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_DIR}")
  get_filename_component(bindir "${directory}" ABSOLUTE
	BASE_DIR "${MODULE_BIN_DIR}")  
  get_filename_component(listfile "CMakeLists.txt" ABSOLUTE
	BASE_DIR "${source}")
  # no return here because we have to make sure the correct commit is checked out 
  set(options)
  set(onevalue FUNCTION)
  set(multivalue GIT)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  if(A_GIT)
	add_module_git("${directory}" "${source}" "${listfile}" RESULT ${A_GIT})
	if(RESULT)
	  file(TIMESTAMP "${listfile}" timestamp)
	  if(timestamp)
	  else(timestamp)
		message(FATAL_ERROR "no listfile found ${directory} ${A_GIT}")
	  endif(timestamp)
	  safely_add_subdir("${source}" "${bindir}")
	  return()
	endif(RESULT)
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not clone ${directory} by any method!")
endfunction(add_module)

set(ENV{__ADD_MODULE_INCLUDED__} 1)
