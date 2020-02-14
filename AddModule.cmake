if(ENV{__ADD_MODULE_INCLUDED__})
  # that should also work for any other submodules stupidly using it?
  return()
endif()

set(ADD_MODULE_STRICT_VERSION TRUE CACHE BOOL
  "Set this to OFF and add_module will only warn upon detecting a version mismatch instead of erroring out. May be good to disable when debugging deep submodules with inadequate self tests. A better idea would be to write adequate self tests for those submodules.")

if(NOT MODULE_DIR)
  get_filename_component(moduledir "modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are located")
  get_filename_component(moduledir "bin_modules" ABSOLUTE
	BASE_DIR "${CMAKE_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set(MODULE_BIN_DIR "${moduledir}"
	CACHE
	FILEPATH "Where modules are compiled")
endif(NOT MODULE_DIR)

file(RELATIVE_PATH test "${CMAKE_BINARY_DIR}" "${MODULE_DIR}")
string(SUBSTRING "${test}" 0 3 test)
if("${test}" STREQUAL "../")
  # we're not in the build directory, EVEN THOUGH WE SHOULD BE >:(
else()
  # stop cmake from pitching a fit
  # note this silences some important warnings for developers who don't set all
  # byproducts properly! I just can't convince cmake that these modules are configure time
  # created, so if they're in the build tree it just assumes that they're unexpected byproducts
  # generated at build time by some poorly designed custom command.
  # this does nothing without include(AddModule NO_POLICY_SCOPE)!
  cmake_policy(SET CMP0058 NEW)
endif()


if(TARGET _cmake_sux_add_module)
else()
  add_custom_target(_cmake_sux_add_module)
  define_property(TARGET
	PROPERTY DIRS_ADDED
	BRIEF_DOCS "Subdirs already added by add_module"
	FULL_DOCS "FU")
endif()

function (safely_add_subdir source binary)
  # the SUBDIRECTORIES property is useless
  # because even if you add_subdirectory in a different source dir
  # it still errors out, with no way to tell which source dir had the subdir
  get_property(dirs_added TARGET _cmake_sux_add_module
	PROPERTY dirs_added)
  list(FIND dirs_added "${source}" result)
  if(NOT result EQUAL -1)
	return()
  endif()
  add_subdirectory("${source}" "${binary}")
  list(APPEND dirs_added "${source}")
  set_property(TARGET _cmake_sux_add_module
	PROPERTY dirs_added "${dirs_added}")
endfunction(safely_add_subdir)

function (add_module_git directory source RESULT commit)
  get_property(prop GLOBAL PROPERTY "add_module_git_${source}" DEFINED)
  if(prop)
	get_property(prop GLOBAL PROPERTY "add_module_git_${source}")
	if(NOT prop STREQUAL commit)
	  message(FATAL_ERROR
		"Need to have the same commit hash for ${directory} ${prop} != ${commit} ${source}")
	else()
	  #message("OK yay got commit ${commit} again")
	endif()
	return()
  endif()
  define_property(GLOBAL PROPERTY "add_module_git_${source}"
	BRIEF_DOCS "no"
	FULL_DOCS "no")
  set_property(GLOBAL PROPERTY "add_module_git_${source}" "${commit}")
  cmake_parse_arguments(PARSE_ARGV 5 GIT
	"NOSHALLOW;RECURSE" "SIGNER" "SIGNERS")
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
	  message(FATAL_ERROR "Couldn't init a git repository? ${result}")
	endif()
  endif(NOT dotgit)
  if(GIT_SIGNER OR GIT_SIGNERS)
	include(gpg)
	if(GIT_SIGNERS)
	  foreach(signer IN LISTS GIT_SIGNERS)
		gpg_require_signer("${signer}")
	  endforeach()
	endif()
	if(GIT_SIGNER)
	  gpg_require_signer("${GIT_SIGNER}")
	endif()
	git(config --replace-all merge.verify-signatures true)
	macro (git)
	  # redefine this to use the new home...
	  execute_process(
		COMMAND env GNUPGHOME="${GNUPG_HOME}" git ${ARGV}
		WORKING_DIRECTORY "${temp}"
		RESULT_VARIABLE result)
	endmacro(git)
  endif(GIT_SIGNER OR GIT_SIGNERS)

  foreach(url IN LISTS GIT_UNPARSED_ARGUMENTS)
	git(remote set-url origin "${url}")
	if(NOT GIT_NOSHALLOW)
	  # https://stackoverflow.com/questions/31278902/how-to-shallow-clone-a-specific-commit-with-depth-1
	  if(result EQUAL 0)
		git(fetch ${GIT_RECURSE} --depth 1 origin "${commit}" ERROR_QUIET)
		if(result EQUAL 0)
		  git(checkout FETCH_HEAD)
		endif()
	  endif()
	else(NOT GIT_NOSHALLOW)
	  git(pull ${GIT_RECURSE} origin "${commit}" )
	endif(NOT GIT_NOSHALLOW)
	if(result EQUAL 0)
	  git(checkout "${commit}" ERROR_QUIET OUTPUT_QUIET)
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
	if(ADD_MODULE_STRICT_VERSION)
	  message(FATAL_ERROR "URL ${url} failed for GIT ${directory}")
	else()
	  message(WARNING "URL ${url} failed for GIT ${directory}")
	endif()
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
  set(options FOREIGN)
  set(onevalue FUNCTION)
  set(multivalue GIT)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  if(A_GIT)
	add_module_git("${directory}" "${source}" RESULT ${A_GIT})
	if(RESULT)
	  if(NOT A_FOREIGN)
		file(TIMESTAMP "${listfile}" timestamp)
		if(timestamp)
		else(timestamp)
		  message(FATAL_ERROR "no listfile found ${directory} ${A_GIT}")
		endif(timestamp)
		safely_add_subdir("${source}" "${bindir}")
	  else()
		set("${directory}_source" "${source}" PARENT_SCOPE)
	  endif()
	  return()
	endif(RESULT)
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not clone ${directory} by any method!")
endfunction(add_module)

set(ENV{__ADD_MODULE_INCLUDED__} 1)

