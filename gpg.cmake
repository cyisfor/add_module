set(GNUPG_HOME "${CMAKE_BINARY_DIR}/gnupg"
  CACHE PATH
  "The automatic repository home for gnupg")

if(NOT TARGET _cmake_sux_gpg)
  add_custom_target(_cmake_sux_gpg)
  define_property(TARGET
	PROPERTY checked_signers
	BRIEF_DOCS "Signers we already checked to exist"
	FULL_DOCS "natch")
  define_property(TARGET
	PROPERTY list_dir
	BRIEF_DOCS "The cmake list dir for this target"
	FULL_DOCS "ditto")
endif()

set_property(TARGET _cmake_sux_gpg PROPERTY list_dir
  "${CMAKE_CURRENT_LIST_DIR}")

function (gpg resultcmakesux)
  cmake_parse_arguments(PARSE_ARGV 1 A "INTERACTIVE;NOHOME" "HOME;INPUT;INPUT_FILE;OUTPUT_VARIABLE;OUTPUT_FILE" "")
  if(A_INPUT)
	# input dynamically as a stdin pipe to gpg
	set(A_INPUT "${A_INPUT} |")
  endif()
  if(A_INTERACTIVE)
	set(A_INTERACTIVE "")
  else()
	set(A_INTERACTIVE
	  "--batch --with-colons --no-tty --yes")
  endif()
  if(A_NOHOME)
	unset(ENV{GNUPGHOME})
  else()
	if(A_HOME)
	  set(ENV{GNUPGHOME} "${A_HOME}")
	else()
	  set(A_HOME "${GNUPG_HOME}")
	  set(ENV{GNUPGHOME} "${GNUPG_HOME}")
	endif()
	function (checkdir)
	  file(TIMESTAMP "${A_HOME}" res)
	  if(res)
	  else()
		set(gpgtemphome ".temphome")
		# ugh... cmake sucks
		set(derp "${CMAKE_BINARY_DIR}/foo${gpgtemphome}")
		file(MAKE_DIRECTORY "${derp}")
		file(MAKE_DIRECTORY "${derp}/${gpgtemphome}")
		file(COPY "${derp}/${gpgtemphome}"
		  DESTINATION "${CMAKE_BINARY_DIR}"
		  DIRECTORY_PERMISSIONS
		  OWNER_READ OWNER_WRITE OWNER_EXECUTE)
		file(REMOVE_RECURSE "${derp}")
		# ...
		file(RENAME "${CMAKE_BINARY_DIR}/${gpgtemphome}" "${A_HOME}")
			file(MAKE_DIRECTORY "${A_HOME}")
	  endif()
	  set(ENV{GNUPGHOME} "${GNUPG_HOME}")
	endfunction(checkdir)
	checkdir()
  endif(A_NOHOME)
  
  if(A_INPUT_FILE)
	set(A_INPUT_FILE "INPUT_FILE ${A_INPUT_FILE}")
  endif()
  if(A_OUTPUT_VARIABLE)
	set(A_OUTPUT_VARIABLE "OUTPUT_VARIABLE ${A_OUTPUT_VARIABLE}")
  endif()
  if(A_OUTPUT_FILE)
	set(A_OUTPUT_FILE "OUTPUT_FILE ${A_OUTPUT_FILE}")
  endif()
  # XXX: cmake won't escape the arguments! Now what?
  # not a problem for our use of gpg specifically though
  list(JOIN A_UNPARSED_ARGUMENTS " " args)

  get_property(list_dir TARGET _cmake_sux_gpg PROPERTY list_dir)
  if("${list_dir}/gpg_thing.cmake" IS_NEWER_THAN "derpthing.cmake")
	message(WARNING "Need new derpthing.")
	configure_file("${list_dir}/gpg_thing.cmake" "derpthing.cmake")
  endif()
  # this is the ONLY WAY to do eval in cmake, which hardcodes keywords of execute_program
  
  include("${CMAKE_CURRENT_BINARY_DIR}/derpthing.cmake")

  set("${resultcmakesux}" "${${resultcmakesux}}" PARENT_SCOPE)
endfunction(gpg)

function(gpgorfail)
  gpg(result ${ARGV})
  if(NOT result EQUAL 0)
	message(FATAL_ERROR "(${result}) Couldn't run gpg ${ARGV}")
  endif()
endfunction(gpgorfail)

function(gpg_parse_signer gpgtemp result)
  file(STRINGS "${gpgtemp}" lines)
  list(LENGTH lines linelen)
  if(linelen EQUAL 1)
	set("${result}" TRUE PARENT_SCOPE)
  else()
	set("${result}" FALSE PARENT_SCOPE)
  endif()
endfunction(gpg_parse_signer)

function(gpg_require_signer signer)
  get_property(checked TARGET _cmake_sux_gpg
	PROPERTY checked_signers)
  list(FIND checked "${signer}" result)
  if(NOT result EQUAL -1)
	return()
  endif()
  set(gpgtemp "${GNUPG_HOME}/.temp")
  gpg(result --list-keys "${signer}" OUTPUT_QUIET)
  if(result EQUAL 0)
	message("git signer ${signer} found.")
  else()
	message("git signer ${signer} not found. Can it be imported from global default?")
	gpg(result NOHOME --list-keys "${signer}" OUTPUT_QUIET)

	if(result EQUAL 0)
	  message("yes!")
	  set(output "${GNUPG_HOME}/.tempout")
	  gpg(result NOHOME --export "${signer}" OUTPUT_FILE "${gpgtemp}")
	  # need import
	  gpgorfail(--import "${gpgtemp}")
	else()
	  message(FATAL_ERROR "nope. trying to receive it...")
	  gpgorfail(--recv-key "${signer}")
	endif()
  endif()
  # set to ultimate trust (for our local module GNUPGHOME)
  gpgorfail(INPUT "echo ${signer}:6:" --import-ownertrust OUTPUT_QUIET)
  list(APPEND checked "${signer}")
  set_property(TARGET _cmake_sux_gpg
	PROPERTY checked_signers "${checked}")
endfunction(gpg_require_signer)
