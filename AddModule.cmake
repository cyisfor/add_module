if(ENV{__ADD_MODULE_INCLUDED__})
  # that should also work for any other submodules stupidly using it?
  return()
endif()

set(ADD_MODULE_STRICT_VERSION TRUE CACHE BOOL
  "Set this to OFF and add_module will only warn upon detecting a version mismatch instead of erroring out. May be good to disable when debugging deep submodules with inadequate self tests. A better idea would be to write adequate self tests for those submodules.")

function(moduledirs name source binary)
  get_filename_component(moduledir "modules/${name}" ABSOLUTE
	BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set("${source}" "${moduledir}" PARENT_SCOPE)
  get_filename_component(moduledir "bin_modules/${name}" ABSOLUTE
	BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
  file(MAKE_DIRECTORY "${moduledir}")
  set("${binary}" "${moduledir}" PARENT_SCOPE)
endif(NOT MODULE_DIR)

# stop cmake from pitching a fit because our sources are in the build
# directory...
# note this silences some important warnings for developers who don't set all
# byproducts properly! I just can't convince cmake that these modules are
# configure time created, so if they're in the build tree it just assumes
# that they're unexpected byproducts generated at build time by some poorly
# designed custom command.
# this does nothing without include(AddModule NO_POLICY_SCOPE)!
cmake_policy(SET CMP0058 NEW)

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

function (check_commit have type source)
  set("${have}" FALSE PARENT_SCOPE)
  get_property(prop GLOBAL PROPERTY "add_module_${type}_${source}" DEFINED)
  if(prop)
	get_property(prop GLOBAL PROPERTY "add_module_${type}_${source}")
	if(NOT prop STREQUAL commit)
	  if(ADD_MODULE_STRICT_VERSION)
		message(FATAL_ERROR
		  "Need to have the same commit hash for ${name} ${prop} != ${commit} ${source}")
	  else()
		message(WARNING
		  "Need to have the same commit hash for ${name} ${prop} != ${commit} ${source}")
	  endif()
	else()
	  set("${have}" TRUE PARENT_SCOPE)
	  #message("OK yay got commit ${commit} again")
	endif()
  else(prop)
	define_property(GLOBAL PROPERTY "add_module_${type}_${source}"
	  BRIEF_DOCS "no"
	  FULL_DOCS "no")
	set_property(GLOBAL PROPERTY "add_module_${type}_${source}" "${commit}")
  endif(prop)
endfunction(check_commit)

function (add_module_git name sourcename binaryname RESULT commit)
  check_commit(have git "${commit}")
  if(have)
	return()
  endif()

  moduledirs("${name}-${commit}" source binary)
  set("${sourcename}" "${source}" PARENT_SCOPE)
  set("${binaryname}" "${binary}" PARENT_SCOPE)
  
  cmake_parse_arguments(PARSE_ARGV 4 GIT
	"NOSHALLOW;RECURSE" "SIGNER" "SIGNERS")

  get_filename_component(dotgit ".git" ABSOLUTE
	BASE_DIR "${source}")
  file(TIMESTAMP "${dotgit}" dotgit)
  if(dotgit)
	# already there yo
	set(temp "${source}")
  else(dotgit)
	get_filename_component(temp "../temp" ABSOLUTE
	  BASE_DIR "${source}")
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
		git(fetch ${GIT_RECURSE} --tags --depth 1 origin "${commit}" ERROR_QUIET)
		if(result EQUAL 0)
		  git(checkout FETCH_HEAD)
		endif()
	  endif()
	else(NOT GIT_NOSHALLOW)
	  git(pull ${GIT_RECURSE} origin "${commit}" )
	  if(result EQUAL 0)
		git(checkout "${commit}" ERROR_QUIET OUTPUT_QUIET)
		if(NOT result EQUAL 0)
		  message(FATAL_ERROR "Could not checkout commit ${commit} from ${name}")
		endif()
	  endif()	
	endif(NOT GIT_NOSHALLOW)
	if(result EQUAL 0)
	  if(NOT dotgit)
		file(RENAME "${temp}" "${source}")
		file(REMOVE_RECURSE "${temp}")
	  endif(NOT dotgit)
	  set("${RESULT}" TRUE PARENT_SCOPE)
	  return()
	endif(result EQUAL 0)
	message(WARNING "URL ${url} failed for GIT ${name}")
  endforeach(url in LISTS GIT_UNPARSED_ARGUMENTS)
  message(WARNING
	"Could not clone ${name} from any of its GIT URIs!")
  set("${RESULT}" FALSE PARENT_SCOPE)
  if(NOT dotgit)
	file(REMOVE_RECURSE "${temp}")
  endif(NOT dotgit)
endfunction(add_module_git)

function(add_module_fossil directory source RESULT commit)
  check_commit(have fossil "${commit}")
  if(have)
	return()
  endif()
  set(fossildb "${MODULE_DIR}/${name}.fossil")
  get_filename_component(temp "temp" ABSOLUTE
	BASE_DIR "${MODULE_DIR}")
  macro (fossil command)
	execute_process(
	  COMMAND fossil ${command} ${ARGN}
	  WORKING_DIRECTORY "${temp}"
	  RESULT_VARIABLE result)
	if(NOT (result EQUAL 0))
	  message(WARNING "fossil fail ${ARGV}")
	  set("${RESULT}" "${result}" PARENT_SCOPE)
	  return()
	endif()
  endmacro(fossil)
  file(TIMESTAMP "${source}" alreadyhave)
  if(alreadyhave)
	# already there yo
	set(temp "${source}")
	fossil(update --verbose "${commit}")
  else(alreadyhave)
	file(REMOVE_RECURSE "${temp}")
	file(MAKE_DIRECTORY "${temp}")
	file(TIMESTAMP "${fossildb}" havefoss)
	if(NOT havefoss)
	  function (find)
		foreach(url IN LISTS ARGV)
		  file(TIMESTAMP "${url}" STAMP)
		  if(STAMP)
			file(COPY "${url}" DESTINATION "${temp}")
			# cmake sucks
			string(REGEX REPLACE ".*/" "" base "${url}")
			file(RENAME "${temp}/${base}" "${fossildb}")
			return()
		  endif()
		  fossil(clone --verbose "${url}" "${fossildb}")
		  if(result)
			return()
		  endif()
		endforeach()
		message("umm ${ARGV}")
		message(FATAL_ERROR "Could not clone from any of these URLS! ${ARGV}")
	  endfunction(find)
	  find(${ARGN})
	endif()
	file(MAKE_DIRECTORY "${temp}")
	fossil(open "${fossildb}" "${commit}")
	file(RENAME "${temp}" "${source}")
  endif(alreadyhave)
  set("${RESULT}" TRUE PARENT_SCOPE)
endfunction(add_module_fossil)

function (add_module name)
  # NOT current binary dir
  moduledirs(name source binary)
  # no return here because we have to make sure the correct commit is checked out
  set(options FOREIGN)
  set(onevalue FUNCTION)
  set(multivalue GIT FOSSIL)
  cmake_parse_arguments(PARSE_ARGV 1 A
	"${options}" "${onevalue}" "${multivalue}")
  macro (whendone source binary)
	if(RESULT)
	  if(NOT A_FOREIGN)
		get_filename_component(listfile "CMakeLists.txt" ABSOLUTE
		  BASE_DIR "${source}")
		file(TIMESTAMP "${listfile}" timestamp)
		if(timestamp)
		else(timestamp)
		  message(FATAL_ERROR "no listfile found for ${name}")
		endif(timestamp)
		safely_add_subdir("${source}" "${binary}")
	  endif()
	  get_filename_component(source "${source}" ABSOLUTE)
	  set("${name}_source" "${source}" PARENT_SCOPE)
	  return()
	endif(RESULT)
  endmacro()
  if(A_GIT)
	add_module_git("${name}" source binary RESULT ${A_GIT})
	whendone("${source}" "${binary}")
  elseif(A_FOSSIL)
	add_module_fossil("${name}" source binary RESULT ${A_FOSSIL})
	whendone("${source}" "${binary}")
  else(A_GIT)
	message(FATAL_ERROR
	  "Must specify either FOSSIL or GIT! TODO: add svn, mercurial, etc")
  endif(A_GIT)
  message(FATAL_ERROR
	"Could not find a method that worked for ${name}!")
endfunction(add_module)

set(ENV{__ADD_MODULE_INCLUDED__} 1)
