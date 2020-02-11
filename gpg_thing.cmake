execute_process(
  COMMAND_ECHO STDOUT
  COMMAND ${A_INPUT}
  gpg
  ${A_INTERACTIVE}
  ${args}
  RESULT_VARIABLE "${resultcmakesux}"
  ${A_INPUT_FILE}
  ${A_OUTPUT_FILE}
  ${A_OUTPUT_VARIABLE})
