#ifndef NATIVE_REGEX_H
#define NATIVE_REGEX_H
#include <stddef.h>
#include <stdint.h>

typedef struct nh_regex nh_regex;
typedef struct {
  int status;
  size_t location;
  size_t length;
  int dispatch_index;
} nh_match;

nh_regex *nh_regex_compile(
  const uint16_t *pattern,
  size_t length,
  int case_insensitive,
  int *error_code,
  size_t *error_offset
);
void nh_regex_free(nh_regex *regex);
nh_match nh_regex_match(
  nh_regex *regex,
  const uint16_t *subject,
  size_t subject_length,
  size_t start_offset,
  const uint32_t *dispatch_groups,
  size_t dispatch_count
);
#endif
