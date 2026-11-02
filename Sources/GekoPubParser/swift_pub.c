#define SP_IMPLEMENTATION
#include "swift_pub.h"
#include "include/GekoPubParser.h"

GekoPubParserResult geko_public_api_parse(const char *file_path)
{
    GekoPubParserResult result = {0};

    if (file_path == NULL) {
        result.status = GEKO_PUB_PARSER_ERROR;
        result.error_code = 1;
        return result;
    }

    SpInputBuf *input = sp_input_buf_create();

    if (input == NULL) {
        result.status = GEKO_PUB_PARSER_ERROR;
        result.error_code = 2;
        return result;
    }

    int status = sp_input_buf_open(input, (char *)file_path);

    if (status != 0) {
        result.status = GEKO_PUB_PARSER_ERROR;
        result.error_code = 3;
        sp_input_buf_destroy(input);
        return result;
    }

    SpInterfaceOutput output = {0};

    status = sp_interface_calculate_public(input, &output);

    sp_input_buf_close(input);
    sp_input_buf_destroy(input);

    if (status != 0) {
        free(output.buf);

        if (status == 1) {
            result.status = GEKO_PUB_PARSER_UNSAFE;
            result.reason_code =
                GEKO_PUB_PARSER_REASON_UNSUPPORTED_SYNTAX;
        } else {
            result.status = GEKO_PUB_PARSER_ERROR;
            result.error_code = status == 2 ? 2 : 4;
        }

        return result;
    }

    result.status = GEKO_PUB_PARSER_SAFE;
    result.text = output.buf;
    result.length = output.size;

    return result;
}

void geko_public_api_result_free(GekoPubParserResult *result)
{
    if (result == NULL) {
        return;
    }

    free(result->text);

    result->text = NULL;
    result->length = 0;
    result->error_code = 0;
    result->status = GEKO_PUB_PARSER_SAFE;
    result->reason_code = GEKO_PUB_PARSER_REASON_NONE;
}
