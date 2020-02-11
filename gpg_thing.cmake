execute_process(
  COMMAND ${A_INPUT}
  gpg
  ${A_INTERACTIVE}
  ${args}
  RESULT_VARIABLE "${resultcmakesux}"
  ERROR_QUIET
  ${A_INPUT_FILE}
  ${A_OUTPUT_FILE}
  ${A_OUTPUT_VARIABLE})
