#include <stdint.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>

// TODO: Support macroses and attributes
// TODO: Support strings (including interpolation)
// TODO: Support default arguments
// TODO: Support computed properties - getters, setters, etc.
// TODO: Support interfaces - needs newlines as tokens
// TODO: Support return values

#define SP_READ_BUF_SIZE 1024 * 64 // 64 kB

typedef struct {
	char buf[SP_READ_BUF_SIZE];
	int fd;
	int bytes_available;
	int pos;
	int at_end;
} SpInputBuf;

typedef enum {
	SP_TOK_KIND_EOF, // end of file

	SP_TOK_KIND_ID, // var name or other identifier

	// keywords
	SP_TOK_KIND_FUNC,
	SP_TOK_KIND_PUBLIC,
	SP_TOK_KIND_PRIVATE,
	SP_TOK_KIND_OPEN,
	SP_TOK_KIND_INTERNAL,
    SP_TOK_KIND_IMPORT,
    SP_TOK_KIND_LET,
    SP_TOK_KIND_VAR,
	SP_TOK_KIND_INIT,
	SP_TOK_KIND_CLASS,
	SP_TOK_KIND_STRUCT,
    SP_TOK_KIND_ENUM,
	SP_TOK_KIND_ACTOR,

	SP_TOK_KIND_KEY_END,

	// single char tokens
	SP_TOK_KIND_OPEN_BR, // '('
	SP_TOK_KIND_CLOSING_BR, // ')'
	SP_TOK_KIND_OPEN_CBR, // '{'
	SP_TOK_KIND_CLOSING_CBR, // '}'
	SP_TOK_KIND_OPEN_SBR, // '['
	SP_TOK_KIND_CLOSING_SBR, // ']'
	SP_TOK_KIND_LESS_THAN, // '<'
	SP_TOK_KIND_MORE_THAN, // '>'
    SP_TOK_KIND_COMMA, // ','
    SP_TOK_KIND_COLON, // ':'
    SP_TOK_KIND_EQUAL, // '='
    SP_TOK_KIND_NEWLINE, // '\n'

	SP_TOK_KIND_UNKNOWN,
} SpTokenKind;

#define SP_KEYWORD_COUNT SP_TOK_KIND_KEY_END - SP_TOK_KIND_FUNC
#define SP_SINGLE_CHAR_TOKEN_COUNT SP_TOK_KIND_UNKNOWN - SP_TOK_KIND_OPEN_BR

typedef struct {
	char *buf;
	size_t capacity;
	size_t size;
} SpInterfaceOutput;


char *keywords[SP_KEYWORD_COUNT] = {
	// must be the same order as in SpTokenKind enum
    "func",
    "public",
    "private",
    "open",
    "internal",
    "import",
    "let",
    "var",
    "init",
    "class",
    "struct",
    "enum",
    "actor",
};

char single_char_tokens[SP_SINGLE_CHAR_TOKEN_COUNT] = {
	// must be the same order as in SpTokenKind enum
    '(',
    ')',
    '{',
    '}',
    '[',
    ']',
    '<',
    '>',
    ',',
    ':',
    '=',
    '\n',
};

typedef struct {
	char *buf;
	size_t size;
	size_t capacity;
	SpTokenKind kind;
} SpLexToken;

// file reading functions
SpInputBuf* sp_input_buf_create();
int sp_input_buf_open(SpInputBuf *buf, char *file);
int sp_input_buf_read_if_needed(SpInputBuf *buf);
char sp_input_buf_read_char(SpInputBuf *buf);
char sp_input_buf_peek_char(SpInputBuf *buf);
void sp_input_buf_close(SpInputBuf *buf);
void sp_input_buf_destroy(SpInputBuf *buf);

// lexer functions
void sp_lex_token_reset(SpLexToken *tok);
int sp_lex_token_increase_capacity(SpLexToken *tok);
int sp_lex_token_add_char(SpLexToken *tok, char ch);
int sp_lex_token_close(SpLexToken *tok);
int sp_lex_key_or_id(SpInputBuf *buf, SpLexToken *tok);
int sp_lex_skip_whitespace(SpInputBuf *buf);
int sp_lex_next_token(SpInputBuf *buf, SpLexToken *tok);

// interface calculation functions
int sp_interface_calculate_public(SpInputBuf *buf, SpInterfaceOutput *output);

#ifdef SP_IMPLEMENTATION

SpInputBuf* sp_input_buf_create()
{
	SpInputBuf* result = malloc(sizeof(SpInputBuf));

	if (!result) {
		return NULL; // oom
	}

	result->fd = 0;
	result->bytes_available = 0;
	result->pos = 0;
	result->at_end = 1;

	return result;
}

int sp_input_buf_open(SpInputBuf *buf, char *file)
{
	int fd = open(file, O_RDONLY);
	if (fd < 0) {
		return errno;
	}

	buf->fd = fd;
	buf->bytes_available = 0;
	buf->pos = 0;
	buf->at_end = 0;

	return 0;
}

int sp_input_buf_read_if_needed(SpInputBuf *buf)
{
	if (buf->at_end) {
		return 0;
	}

	if (buf->pos < buf->bytes_available) {
		return buf->bytes_available;
	}

	buf->bytes_available = read(buf->fd, buf->buf, SP_READ_BUF_SIZE);

	if (buf->bytes_available < 1) {
		buf->at_end = 1;
	}

	return buf->bytes_available;
}

char sp_input_buf_read_char(SpInputBuf *buf)
{
	sp_input_buf_read_if_needed(buf);

	if (buf->at_end) {
		return '\0';
	}

	char ch = buf->buf[buf->pos];
	buf->pos++;
	return ch;
}

char sp_input_buf_peek_char(SpInputBuf *buf)
{
	sp_input_buf_read_if_needed(buf);

	if (buf->at_end) {
		return '\0';
	}

	return buf->buf[buf->pos];
}

void sp_input_buf_close(SpInputBuf *buf)
{
	close(buf->fd);
}

void sp_input_buf_destroy(SpInputBuf *buf)
{
	free(buf);
}

// lexer

void sp_lex_token_reset(SpLexToken *tok)
{
	tok->size = 0;
	tok->kind = SP_TOK_KIND_UNKNOWN;
}

int sp_lex_token_increase_capacity(SpLexToken *tok)
{
    if (tok->capacity > SIZE_MAX / 2) {
        return 1;
    }
    
    size_t new_capacity = tok->capacity == 0 ? 256 : tok->capacity * 2;
    char *new_buf = realloc(tok->buf, new_capacity);
    
    if (new_buf == NULL) {
        return 1;
    }
    
    tok->buf = new_buf;
    tok->capacity = new_capacity;

    return 0;
}

int sp_lex_token_add_char(SpLexToken *tok, char ch)
{
	if (tok->size >= tok->capacity) {
        if (sp_lex_token_increase_capacity(tok) != 0) {
            return 2;
        }
	}
	tok->buf[tok->size] = ch;
	tok->size += 1;

	return 0;
}

int sp_lex_token_close(SpLexToken *tok)
{
	if (tok->size >= tok->capacity) {
        if (sp_lex_token_increase_capacity(tok) != 0) {
            return 2;
        }
	}
	tok->buf[tok->size] = '\0';

	return 0;
}

int sp_lex_key_or_id(SpInputBuf *buf, SpLexToken *tok)
{
	char ch = sp_input_buf_peek_char(buf);

    while (
		ch < 0 || // utf8, probably identifier
		(ch >= 'a' && ch <= 'z') ||
		(ch >= 'A' && ch <= 'Z') ||
		(ch >= '0' && ch <= '9') ||
		ch == '_' ||
		ch == '`'
	) {
		ch = sp_input_buf_read_char(buf);
        
        
		int status = sp_lex_token_add_char(tok, ch);
        if (status != 0) {
            return status;
        }
        
		status = sp_lex_token_close(tok);
        if (status != 0) {
            return status;
        }

		ch = sp_input_buf_peek_char(buf);
	}

    tok->kind = SP_TOK_KIND_ID;

	for (int i = 0; i < SP_KEYWORD_COUNT; i++) {
		if (strcmp(keywords[i], tok->buf) == 0) {
			tok->kind = SP_TOK_KIND_FUNC + i;
			break;
		}
	}

	return 0;
}

int sp_lex_skip_whitespace(SpInputBuf *buf)
{
	char ch = sp_input_buf_peek_char(buf);

	while (
		ch == ' ' ||
		ch == '\t' ||
		ch == '\r'
	) {
		sp_input_buf_read_char(buf);
		ch = sp_input_buf_peek_char(buf);
	}

	return 0;
}

int sp_lex_skip_line(SpInputBuf *buf)
{
	// TODO: check if CRLF is working correctly
	char ch = sp_input_buf_peek_char(buf);

	while (ch != '\n' && ch != '\0') {
		sp_input_buf_read_char(buf);
		ch = sp_input_buf_peek_char(buf);
	}

	return 0;
}

int sp_lex_skip_multiline_comment(SpInputBuf *buf)
{
	char ch = sp_input_buf_read_char(buf); // skip '*'
	ch = sp_input_buf_read_char(buf);

	int nested_level = 1;

	while (ch != '\0') {
		if (ch == '*') {
			ch = sp_input_buf_read_char(buf);
			if (ch == '/') {
				nested_level -= 1;
				if (nested_level == 0) {
					return 0;
				}
			}
		} else if (ch == '/') {
			ch = sp_input_buf_read_char(buf);
			if (ch == '*') {
				nested_level += 1;
			}
		}

		ch = sp_input_buf_read_char(buf);
	}

	return 0;
}

int sp_lex_next_token(SpInputBuf *buf, SpLexToken *tok)
{
	sp_lex_token_reset(tok);

	sp_lex_skip_whitespace(buf);

	char ch = sp_input_buf_read_char(buf);
	int status = sp_lex_token_add_char(tok, ch);
    if (status != 0) {
        return status;
    }

	if (ch == '\0') {
		tok->size = 0;
		tok->kind = SP_TOK_KIND_EOF;
		return 0;
	}

	if (ch == '/') {
		char peeked_ch = sp_input_buf_peek_char(buf);

		if (peeked_ch == '/') {
			sp_lex_skip_line(buf);
		} else if (peeked_ch == '*') {
			sp_lex_skip_multiline_comment(buf);
		} else {
			// TODO: parse regex
			return 1;
		}
		// TODO: get rid of recursion
		return sp_lex_next_token(buf, tok);
	}

    if (
		ch < 0 || // utf8, probably identifier
		(ch >= 'a' && ch <= 'z') ||
		(ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') ||
		ch == '_' ||
		ch == '`'
	) {
		return sp_lex_key_or_id(buf, tok);
	}

	for (int i = 0; i < SP_SINGLE_CHAR_TOKEN_COUNT; i++) {
		if (single_char_tokens[i] == ch) {
			tok->kind = SP_TOK_KIND_OPEN_BR + i;
		}
	}

	

    return sp_lex_token_close(tok);;
}

// interface calculation

void sp_interface_output_reset(SpInterfaceOutput *output)
{
	output->size = 0;
}

int sp_interface_output_increase_capacity(SpInterfaceOutput *output, size_t min_capacity)
{
    size_t new_capacity = output->capacity == 0 ? 256 : output->capacity;
    
    while (new_capacity < min_capacity) {
        if (new_capacity > SIZE_MAX / 2) {
            return 1;
        }
        new_capacity *= 2;
    }
    
    char *new_buf = realloc(output->buf, new_capacity);
    
    if (new_buf == NULL) {
        return 1;
    }
    
    output->buf = new_buf;
    output->capacity = new_capacity;
    return 0;
}

int sp_interface_output_append_string(SpInterfaceOutput *output, char *str)
{
	size_t str_len = strlen(str);
    
    if (str_len > SIZE_MAX - output->size) {
        return 2;
    }
    size_t required_size = output->size + str_len;
    
    if (required_size > output->capacity) {
        if (sp_interface_output_increase_capacity(output, required_size) != 0) {
            return 2;
        }
    }
    
    if (str_len > 0) {
        memcpy(output->buf + output->size, str, str_len);
    }
    
    output->size += str_len;

    return 0;
}

int sp_interface_output_append_token(SpInterfaceOutput *output, SpLexToken *tok)
{
    size_t separator_size = output->size > 0 ? 1 : 0;
    
    if (separator_size > SIZE_MAX - output->size) {
        return 2;
    }
    
    size_t required_size = output->size + separator_size;

    if (tok->size > SIZE_MAX - required_size) {
        return 2;
    }

    required_size += tok->size;

    if (required_size > output->capacity) {
        if (sp_interface_output_increase_capacity(output, required_size) != 0) {
            return 2;
        }
    }

    if (separator_size > 0) {
        output->buf[output->size++] = ' ';
    }

    if (tok->size > 0) {
        memcpy(output->buf + output->size, tok->buf, tok->size);
    }

    output->size += tok->size;

    return 0;
}

int sp_interface_output_append(SpInterfaceOutput *dst, SpInterfaceOutput *src, int nested_level)
{
    if (src->size == 0) {
        return 0;
    }

    if (nested_level < 0) {
        return 1;
    }

    size_t newline_size = dst->size > 0 ? 1 : 0;

    if ((size_t)nested_level > SIZE_MAX / 4) {
        return 2;
    }

    size_t indent_size = (size_t)nested_level * 4;

    if (newline_size > SIZE_MAX - dst->size) {
        return 2;
    }

    size_t required_size = dst->size + newline_size;

    if (indent_size > SIZE_MAX - required_size) {
        return 2;
    }

    required_size += indent_size;

    if (src->size > SIZE_MAX - required_size) {
        return 2;
    }

    required_size += src->size;

    if (required_size > dst->capacity) {
        if (sp_interface_output_increase_capacity(dst, required_size) != 0) {
            return 2;
        }
    }

    if (newline_size > 0) {
        dst->buf[dst->size++] = '\n';
    }

    for (int i = 0; i < nested_level; i++) {
        memcpy(dst->buf + dst->size, "    ", 4);
        dst->size += 4;
    }

    memcpy(dst->buf + dst->size, src->buf, src->size);
    dst->size += src->size;

    return 0;
}

int sp_interface_output_close(SpInterfaceOutput *output)
{
    if (output->size == SIZE_MAX) {
        return 2;
    }

    size_t required_size = output->size + 1;

    if (required_size > output->capacity) {
        if (sp_interface_output_increase_capacity(output, required_size) != 0) {
            return 2;
        }
    }

    output->buf[output->size] = '\0';

    return 0;
}

int sp_interface_skip_block(SpInputBuf *buf, SpLexToken *tok)
{
    int nested_block_level = 1;

    do {
        int status = sp_lex_next_token(buf, tok);

        if (status != 0) {
            return status;
        }

        if (tok->kind == SP_TOK_KIND_OPEN_CBR) {
            nested_block_level += 1;
        }

        if (tok->kind == SP_TOK_KIND_CLOSING_CBR) {
            nested_block_level -= 1;

            if (nested_block_level <= 0) {
                break;
            }
        }
    } while (tok->kind != SP_TOK_KIND_EOF);

    return 0;
}

typedef enum {
	SP_INTERFACE_KIND_METHOD, // func or var or computed property
	SP_INTERFACE_KIND_OBJECT, // class or struct or actor
	SP_INTERFACE_KIND_UNKNOWN,
} SpInterfaceKind;

typedef enum {
	SP_INTERFACE_VISIBILITY_PRIVATE,
	SP_INTERFACE_VISIBILITY_INTERNAL,
	SP_INTERFACE_VISIBILITY_PUBLIC,
	SP_INTERFACE_VISIBILITY_OPEN,
} SpInterfaceVisibility;

int sp_interface_finish_property(
    SpInterfaceOutput *output,
    SpInterfaceOutput *interface_chunk,
    SpInterfaceVisibility visibility,
    int nested_level,
    int has_explicit_type
) {
    if (visibility < SP_INTERFACE_VISIBILITY_PUBLIC) {
        return 0;
    }
    
    if (!has_explicit_type) {
        return 1; // unsafe: inferred or missing type
    }

    return sp_interface_output_append(
        output,
        interface_chunk,
        nested_level
    );
}

int sp_interface_calculate_public(
    SpInputBuf *buf,
    SpInterfaceOutput *output
) {
    SpInterfaceOutput interface_chunk = {0};
    SpLexToken tok = {0};

    int res = 0;
    SpInterfaceKind kind = SP_INTERFACE_KIND_UNKNOWN;
    SpInterfaceVisibility visibility = SP_INTERFACE_VISIBILITY_INTERNAL;
    int nested_level = 0;
    int is_property = 0;
    int property_has_type = 0;

    while ((res = sp_lex_next_token(buf, &tok)) == 0) {
        switch (tok.kind) {
        case SP_TOK_KIND_EOF:
            goto finalize;

        case SP_TOK_KIND_IMPORT:
            sp_lex_skip_line(buf);
            continue;
            
        case SP_TOK_KIND_CLASS:
        case SP_TOK_KIND_STRUCT:
        case SP_TOK_KIND_ENUM:
        case SP_TOK_KIND_ACTOR:
            kind = SP_INTERFACE_KIND_OBJECT;
            break;

        case SP_TOK_KIND_INIT:
        case SP_TOK_KIND_FUNC:
            kind = SP_INTERFACE_KIND_METHOD;
            break;

        case SP_TOK_KIND_LET:
        case SP_TOK_KIND_VAR:
            is_property = 1;
            property_has_type = 0;
            break;
        case SP_TOK_KIND_COLON:
            if (is_property) {
                property_has_type = 1;
            }
            break;
        case SP_TOK_KIND_EQUAL:
            if (is_property) {
                if (
                    visibility < SP_INTERFACE_VISIBILITY_PUBLIC ||
                    property_has_type
                ) {
                    sp_lex_skip_line(buf);
                    continue;
                }

                res = 1;
                goto cleanup;
            }
            break;
            
        case SP_TOK_KIND_NEWLINE:
            if (is_property) {
                res = sp_interface_finish_property(output, &interface_chunk, visibility, nested_level, property_has_type);
                
                if (res != 0) {
                    goto cleanup;
                }
                
                sp_interface_output_reset(&interface_chunk);
                visibility = SP_INTERFACE_VISIBILITY_INTERNAL;
                kind = SP_INTERFACE_KIND_UNKNOWN;
                is_property = 0;
                property_has_type = 0;
            }
            
            continue;

        case SP_TOK_KIND_PRIVATE:
            visibility = SP_INTERFACE_VISIBILITY_PRIVATE;
            break;

        case SP_TOK_KIND_INTERNAL:
            visibility = SP_INTERFACE_VISIBILITY_INTERNAL;
            break;

        case SP_TOK_KIND_PUBLIC:
            visibility = SP_INTERFACE_VISIBILITY_PUBLIC;
            break;

        case SP_TOK_KIND_OPEN:
            visibility = SP_INTERFACE_VISIBILITY_OPEN;
            break;

        case SP_TOK_KIND_OPEN_CBR:
            if (visibility >= SP_INTERFACE_VISIBILITY_PUBLIC) {
                if (kind == SP_INTERFACE_KIND_METHOD) {
                    res = sp_interface_skip_block(buf, &tok);
                    if (res != 0) {
                        goto cleanup;
                    }

                    res = sp_interface_output_append(
                        output,
                        &interface_chunk,
                        nested_level
                    );
                } else if (kind == SP_INTERFACE_KIND_OBJECT) {
                    res = sp_interface_output_append_token(
                        &interface_chunk,
                        &tok
                    );

                    if (res != 0) {
                        goto cleanup;
                    }

                    res = sp_interface_output_append(
                        output,
                        &interface_chunk,
                        nested_level
                    );

                    if (res == 0) {
                        nested_level += 1;
                    }
                } else {
                    res = 1;
                }
            } else {
                res = sp_interface_skip_block(buf, &tok);
            }

            if (res != 0) {
                goto cleanup;
            }

            sp_interface_output_reset(&interface_chunk);
            kind = SP_INTERFACE_KIND_UNKNOWN;
            visibility = SP_INTERFACE_VISIBILITY_INTERNAL;

            continue;

        case SP_TOK_KIND_CLOSING_CBR:
            if (is_property) {
                res = sp_interface_finish_property(
                    output,
                    &interface_chunk,
                    visibility,
                    nested_level,
                    property_has_type
                );

                if (res != 0) {
                    goto cleanup;
                }

                sp_interface_output_reset(&interface_chunk);
                is_property = 0;
                property_has_type = 0;
            }
            
            res = sp_interface_output_append(
                output,
                &interface_chunk,
                nested_level
            );

            if (res != 0) {
                goto cleanup;
            }

            sp_interface_output_reset(&interface_chunk);

            kind = SP_INTERFACE_KIND_UNKNOWN;
            visibility = SP_INTERFACE_VISIBILITY_INTERNAL;

            nested_level -= 1;

            if (nested_level < 0) {
                res = 1;
                goto cleanup;
            }

            break;

        case SP_TOK_KIND_UNKNOWN:
            res = 1;
            goto cleanup;

        default:
            break;
        }

        res = sp_interface_output_append_token(
            &interface_chunk,
            &tok
        );

        if (res != 0) {
            goto cleanup;
        }
    }

    if (res != 0) {
        goto cleanup;
    }

finalize:
    if (is_property) {
        res = sp_interface_finish_property(
            output,
            &interface_chunk,
            visibility,
            nested_level,
            property_has_type
        );

        if (res != 0) {
            goto cleanup;
        }

        sp_interface_output_reset(&interface_chunk);
    }
    
    res = sp_interface_output_append(
        output,
        &interface_chunk,
        nested_level
    );

    if (res != 0) {
        goto cleanup;
    }

    res = sp_interface_output_close(output);

cleanup:
    free(tok.buf);
    free(interface_chunk.buf);

    return res;
}

#endif
