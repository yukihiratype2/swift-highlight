#define PCRE2_CODE_UNIT_WIDTH 16
#include <pcre2.h>
#include <pthread.h>
#include <stdlib.h>
#include "include/NativeRegex.h"

struct nh_regex {
  pcre2_code *code;
  uint32_t ovector_count;
};

typedef struct {
  pcre2_match_data *match_data;
  uint32_t ovector_count;
} nh_thread_match_data;

static pthread_key_t nh_match_data_key;
static pthread_once_t nh_match_data_key_once = PTHREAD_ONCE_INIT;

static void nh_free_thread_match_data(void *raw) {
  nh_thread_match_data *state = raw;
  if (!state) return;
  pcre2_match_data_free(state->match_data);
  free(state);
}

static void nh_make_match_data_key(void) {
  (void)pthread_key_create(&nh_match_data_key, nh_free_thread_match_data);
}

static pcre2_match_data *nh_match_data(uint32_t count) {
  pthread_once(&nh_match_data_key_once, nh_make_match_data_key);
  nh_thread_match_data *state = pthread_getspecific(nh_match_data_key);
  if (!state) {
    state = calloc(1, sizeof(nh_thread_match_data));
    if (!state || pthread_setspecific(nh_match_data_key, state) != 0) {
      free(state);
      return NULL;
    }
  }
  if (state->ovector_count < count) {
    pcre2_match_data *larger = pcre2_match_data_create(count, NULL);
    if (!larger) return NULL;
    pcre2_match_data_free(state->match_data);
    state->match_data = larger;
    state->ovector_count = count;
  }
  return state->match_data;
}

nh_regex *nh_regex_compile(
  const uint16_t *pattern,
  size_t length,
  int case_insensitive,
  int *error_code,
  size_t *error_offset
) {
  /*
   * ECMAScript keeps \d and \w ASCII-based even in Unicode mode. PCRE2_UCP
   * changes those classes and adds a sizeable property-table cost, so UTF
   * validation is enabled without UCP.
   */
  uint32_t options = PCRE2_MULTILINE | PCRE2_UTF;
  if (case_insensitive) options |= PCRE2_CASELESS;
  int code = 0;
  PCRE2_SIZE offset = 0;
  pcre2_code *compiled = pcre2_compile(
    (PCRE2_SPTR)pattern, length, options, &code, &offset, NULL
  );
  if (!compiled) {
    if (error_code) *error_code = code;
    if (error_offset) *error_offset = offset;
    return NULL;
  }
  (void)pcre2_jit_compile(compiled, PCRE2_JIT_COMPLETE);
  nh_regex *regex = calloc(1, sizeof(nh_regex));
  if (!regex) {
    pcre2_code_free(compiled);
    return NULL;
  }
  regex->code = compiled;
  uint32_t captures = 0;
  if (pcre2_pattern_info(compiled, PCRE2_INFO_CAPTURECOUNT, &captures) != 0) {
    pcre2_code_free(compiled);
    free(regex);
    return NULL;
  }
  regex->ovector_count = captures + 1;
  return regex;
}

void nh_regex_free(nh_regex *regex) {
  if (!regex) return;
  pcre2_code_free(regex->code);
  free(regex);
}

nh_match nh_regex_match(
  nh_regex *regex,
  const uint16_t *subject,
  size_t subject_length,
  size_t start_offset,
  const uint32_t *groups,
  size_t group_count
) {
  nh_match result = {0, 0, 0, -1};
  if (!regex || !subject || start_offset > subject_length) return result;
  pcre2_match_data *match_data = nh_match_data(regex->ovector_count);
  if (!match_data) return result;
  int count = pcre2_match(
    /*
     * Swift.String has already validated Unicode. Revalidating the complete
     * UTF-16 subject for every parser event is both redundant and expensive.
     */
    regex->code, (PCRE2_SPTR)subject, subject_length, start_offset,
    PCRE2_NO_UTF_CHECK,
    match_data, NULL
  );
  if (count < 0) return result;
  PCRE2_SIZE *vector = pcre2_get_ovector_pointer(match_data);
  result.status = 1;
  result.location = vector[0];
  result.length = vector[1] - vector[0];
  for (size_t index = 0; index < group_count; index++) {
    uint32_t group = groups[index];
    if (group < (uint32_t)count && vector[group * 2] != PCRE2_UNSET) {
      result.dispatch_index = (int)index;
      break;
    }
  }
  return result;
}
