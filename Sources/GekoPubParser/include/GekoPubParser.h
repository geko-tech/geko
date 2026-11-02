#ifndef GEKO_PUB_PARSER_H
#define GEKO_PUB_PARSER_H

#include <stddef.h>

typedef enum {
    GEKO_PUB_PARSER_SAFE = 0,
    GEKO_PUB_PARSER_UNSAFE = 1,
    GEKO_PUB_PARSER_ERROR = 2
} GekoPubParserStatus;

typedef enum {
    GEKO_PUB_PARSER_REASON_NONE = 0,
    GEKO_PUB_PARSER_REASON_UNSUPPORTED_SYNTAX = 1
} GekoPubParserUnsafeReason;

typedef struct {
    GekoPubParserStatus status;
    char *text;
    size_t length;
    int error_code;
    GekoPubParserUnsafeReason reason_code;
} GekoPubParserResult;

GekoPubParserResult geko_public_api_parse(const char *file_path);

void geko_public_api_result_free(GekoPubParserResult *result);

#endif
