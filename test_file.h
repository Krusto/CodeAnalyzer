/*

This is a test file from a project I am working on.

*/

#ifndef JSONPARSER_HEADER
#define JSONPARSER_HEADER
/**
 * @file
 * @author Krusto Stoyanov ( k.stoianov2@gmail.com )
 * @brief
 * @version 1.0
 * @date
 *
 * @section LICENSE
 * MIT License
 *
 * Copyright (c) 2024 Krusto
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * @section DESCRIPTION
 *
 * JSONParser Header
 */

/***********************************************************************************************************************
Includes
***********************************************************************************************************************/
#include "CFilesystem.h"
#include "CLog.h"
#include "JSONParserDefs.h"
#include "STDTypes.h"

/***********************************************************************************************************************
Macro definitions
***********************************************************************************************************************/
#define json_get_current_char(parser) ((parser)->buffer[(parser)->offset])
#define json_current_unicode_char(parser)                                      \
  utf8_to_unicode(&json_get_current_char(parser))
#define json_move_to_next_char(parser)                                         \
  ((parser)->offset += utf8_get_char_length(json_get_current_char(parser)))
#define json_move_to_prev_char(parser)                                         \
  ((parser)->offset -= utf8_get_char_length(json_get_current_char(parser)))
#define json_current_char_length(parser)                                       \
  utf8_get_char_length(json_get_current_char(parser))

#define json_check_token(parser, token)                                        \
  (json_get_current_token(parser) == token)
#define json_is_string_start(parser)                                           \
  json_check_token(parser, UNICODE_TOKEN_QUOTATION_MARK)
#define json_is_string_end(parser)                                             \
  json_check_token(parser, UNICODE_TOKEN_QUOTATION_MARK)
#define json_is_escape_character(parser)                                       \
  json_check_token(parser, UNICODE_TOKEN_BACK_SLASH)
#define json_is_array_end(parser)                                              \
  json_check_token(parser, UNICODE_TOKEN_RIGHT_SQUARE_BRACKET)
#define json_is_escaped(parser)                                                \
  (json_get_prev_token(parser) == UNICODE_TOKEN_BACK_SLASH)
#define json_is_node_string(node) (node->valueType == NODE_TYPE_STRING)
#define json_is_node_literal(node) (node->valueType != NODE_TYPE_STRING)
#define json_is_node_object(node) (node->valueType == NODE_TYPE_OBJECT)
#define json_is_object_end(parser)                                             \
  json_check_token(parser, UNICODE_TOKEN_RIGHT_CURLY_BRACKET)
#define json_is_node_array(node) (node->valueType == NODE_TYPE_ARRAY)
#define json_is_node_object_element(node)                                      \
  (node->valueType == NODE_TYPE_OBJECT_ELEMENT)
#define json_is_token_character(unicodeToken)                                  \
  (unicodeToken >= UNICODE_TOKEN_A && unicodeToken <= UNICODE_TOKEN_Z)
#define json_is_char_space(unicodeChar)                                        \
  (unicodeChar == UNICODE_TABULATION || unicodeChar == UNICODE_LINE_FEED ||    \
   unicodeChar == UNICODE_CARRIAGE_RETURN || unicodeChar == UNICODE_SPACE)

/***********************************************************************************************************************
Static function declarations
***********************************************************************************************************************/

static JSONParserResultT json_parse_file(const char *path, JSONParserT *parser);
static void json_print_tree(JSONObjectT *node, uint32_t indent);
static void destroy_json_parser(JSONParserT *parser);
static JSONObjectT *json_parse_value(JSONParserT *parser);
static JSONObjectT *json_parse_literal(JSONParserT *parser);
static JSONStringT *json_parse_string(JSONParserT *parser);
static JSONArrayT *json_parse_array(JSONParserT *parser);
static JSONObjectObjectElementT *json_parse_object_element(JSONParserT *parser);
static JSONObjectObjectT *json_parse_object(JSONParserT *parser);

static JSONTokenT json_get_current_token(JSONParserT *parser);
static JSONTokenT json_get_prev_token(JSONParserT *parser);
static void json_buffer_skip_spaces(JSONParserT *parser);
static void json_check_skip_colon(JSONParserT *parser);
static void json_check_skip_comma(JSONParserT *parser);

static BOOL json_is_literal_true(JSONTokenT *tokens, size_t tokenCount);
static BOOL json_is_literal_false(JSONTokenT *tokens, size_t tokenCount);
static BOOL json_is_literal_null(JSONTokenT *tokens, size_t tokenCount);
static BOOL json_is_unicode_character(UnicodeCharacterT unicodeCharacter);

static JSONStringT *create_node_string(const int8_t *data, size_t length);
static JSONArrayT *create_node_array();
static JSONObjectObjectElementT *json_create_json_object_element(JSONStringT *key, JSONObjectT *value);
static JSONObjectObjectT *json_create_json_object();
static void free_string(JSONStringT *str);
static void free_array(JSONArrayT *arr);
static void free_object_element(JSONObjectObjectElementT *element);
static void free_object(JSONObjectObjectT *object);
static void free_json_tree(JSONObjectT *node);

/***********************************************************************************************************************
Static function definitions
***********************************************************************************************************************/
inline static JSONParserResultT json_parse_file(const char *path, JSONParserT *parser) {

  JSONParserResultT result = JSON_PARSE_RESULT_ERROR;
  LOG_INFO("Parsing %s\n", path);

  int8_t *data;
  size_t filesize;
  FileOpResultT fileReadResult = file_read_utf8(path, &filesize, &data);

  if (FILE_READ_SUCCESFULLY != fileReadResult) {
    result = JSON_PARSE_RESULT_ERROR;
  } else {
    parser->buffer = data;
    parser->length = filesize;
    parser->offset = 0;

    parser->root = json_parse_value(parser);
    if (parser->verboseOutput) {
      json_print_tree(parser->root, 0);
    }
    if (parser->root) {
      result = JSON_PARSE_RESULT_OK;
    }
  }
  return result;
}

inline static void json_print_tree(JSONObjectT *node, uint32_t indent) {
  switch (node->valueType) {
  case NODE_TYPE_OBJECT: {
    JSONObjectObjectT *object = ((JSONObjectObjectT *)node);
    DArrayT *elements = object->elements;
    indent += 4;
    for (size_t i = 0; i < darr_length(elements); i++) {
      json_print_tree((JSONObjectT *)*(long long *)darr_get_ptr(elements, i),
                      indent);
    }
    break;
  }
  case NODE_TYPE_ARRAY:
    WLOG(L"[\n");
    for (size_t i = 0; i < darr_length(((JSONArrayT *)node)->data); i++) {
      json_print_tree((JSONObjectT *)*(long long *)darr_get_ptr(
                          ((JSONArrayT *)node)->data, i),
                      indent);
    }
    for (size_t i = 0; i < indent + 4; i++) {
      WLOG(L" ");
    }
    WLOG(L"]\n");
    break;
  case NODE_TYPE_OBJECT_ELEMENT: {
    JSONObjectObjectElementT *object = ((JSONObjectObjectElementT *)node);
    JSONStringT *key = object->key;
    DStringT *keyStr = key->value;
    WLOG(L"\n");
    for (size_t i = 0; i < indent; i++) {
      WLOG(L" ");
    }
    WLOG(L"Key \"%s\" : ", keyStr->data);
    indent += 2;
    json_print_tree(object->value, indent);
    break;
  }
  case NODE_TYPE_STRING:
    WLOG(L"\"%s\"\n", ((JSONStringT *)node)->value->data);
    break;
  case NODE_TYPE_TRUE:
    WLOG(L"true\n");
    break;
  case NODE_TYPE_FALSE:
    WLOG(L"false\n");
    break;
  case NODE_TYPE_NULL:
    WLOG(L"null\n");
    break;
  default:
    break;
  }
}

inline static void destroy_json_parser(JSONParserT *parser) {
  free_json_tree(parser->root);
  CFREE(parser->buffer, parser->length);
}

inline static JSONObjectT *json_parse_value(JSONParserT *parser) {
  json_buffer_skip_spaces(parser);
  JSONTokenT token = json_get_current_token(parser);

  JSONObjectT *result = NULL;

  switch (token) {
  case UNICODE_TOKEN_LEFT_CURLY_BRACKET:
    result = (JSONObjectT *)json_parse_object(parser);
    break;
  case UNICODE_TOKEN_LEFT_SQUARE_BRACKET:
    result = (JSONObjectT *)json_parse_array(parser);
    break;
  case UNICODE_TOKEN_QUOTATION_MARK:
    result = (JSONObjectT *)json_parse_string(parser);
    break;
  default:
    if (json_is_token_character(token)) {
      result = (JSONObjectT *)json_parse_literal(parser);
    }
    break;
  }
  return result;
}

inline static JSONObjectT *json_parse_literal(JSONParserT *parser) {
  json_buffer_skip_spaces(parser);
  const size_t max_literal_length = 10;
  JSONTokenT tokens[max_literal_length];
  size_t token_count = 0;

  JSONTokenT current_token = json_get_current_token(parser);
  while (json_is_token_character(current_token) &&
         token_count < max_literal_length) {
    tokens[token_count++] = current_token;
    json_move_to_next_char(parser);
    current_token = json_get_current_token(parser);
  }
  if (token_count >= max_literal_length - 1) {
    while (json_is_token_character(current_token)) {
      json_move_to_next_char(parser);
      current_token = json_get_current_token(parser);
    }
  }

  JSONObjectT *result = (JSONObjectT *)malloc(sizeof(JSONObjectT));
  if (json_is_literal_true(tokens, token_count)) {
    result->valueType = NODE_TYPE_TRUE;
  } else if (json_is_literal_false(tokens, token_count)) {
    result->valueType = NODE_TYPE_FALSE;
  } else {
    result->valueType = NODE_TYPE_NULL;
  }

  return result;
}

inline static JSONStringT *json_parse_string(JSONParserT *parser) {
  JSONStringT *result = NULL;
  if (json_is_string_start(parser)) {
    CStringViewT str;
    const int8_t *data =
        &parser->buffer[parser->offset + json_current_char_length(parser)];
    uint32_t length = 0;
    parser->offset += 1;

    JSONTokenT token = json_get_current_token(parser);
    while (!json_is_string_end(parser) || json_is_escape_character(parser)) {
      if (json_is_escaped(parser) && json_is_string_end(parser)) {
        token = UNICODE_TOKEN_NONE;
      }
      length += json_current_char_length(parser);
      json_move_to_next_char(parser);
    }
    if (json_is_string_end(parser)) {
      json_move_to_next_char(parser);
    }

    result = create_node_string(data, length);
  }

  return result;
}

inline static JSONArrayT *json_parse_array(JSONParserT *parser) {
  json_move_to_next_char(parser);

  JSONArrayT *result = create_node_array();

  JSONTokenT token = UNICODE_TOKEN_ALL;
  while (!json_is_array_end(parser)) {
    json_buffer_skip_spaces(parser);
    darr_push_ptr(result->data, json_parse_value(parser));
    json_buffer_skip_spaces(parser);

    json_check_skip_comma(parser);
  }
  json_move_to_next_char(parser);

  return result;
}

inline static JSONObjectObjectElementT *
json_parse_object_element(JSONParserT *parser) {
  JSONObjectObjectElementT *object = NULL;

  json_buffer_skip_spaces(parser);

  JSONObjectT *key = json_parse_value(parser);

  if (key->valueType == NODE_TYPE_STRING) {
    json_buffer_skip_spaces(parser);

    json_check_skip_colon(parser);

    json_buffer_skip_spaces(parser);

    object = json_create_json_object_element((JSONStringT *)key,
                                             json_parse_value(parser));
  } else {
    free_json_tree((JSONObjectT *)key);
  }

  return object;
}

inline static JSONObjectObjectT *json_parse_object(JSONParserT *parser) {
  JSONObjectObjectT *result = NULL;
  json_move_to_next_char(parser);

  JSONTokenT token = UNICODE_TOKEN_ALL;

  result = json_create_json_object();

  while (!json_is_object_end(parser)) {
    darr_push_ptr(result->elements, json_parse_object_element(parser));

    json_buffer_skip_spaces(parser);
    json_check_skip_comma(parser);

    json_buffer_skip_spaces(parser);
  }
  json_move_to_next_char(parser);

  return result;
}

inline static JSONTokenT json_get_current_token(JSONParserT *parser) {
  JSONTokenT result = UNICODE_TOKEN_NONE;
  UnicodeCharacterT unicodeChar = json_current_unicode_char(parser);
  if (json_is_unicode_character(unicodeChar)) {
    result = unicodeChar;
  } else {
    switch (unicodeChar) {
    case UNICODE_QUOTATION_MARK:
    case UNICODE_COMMA:
    case UNICODE_COLON:
    case UNICODE_LEFT_SQUARE_BRACKET:
    case UNICODE_BACK_SLASH:
    case UNICODE_RIGHT_SQUARE_BRACKET:
    case UNICODE_LEFT_CURLY_BRACKET:
    case UNICODE_RIGHT_CURLY_BRACKET:
      result = unicodeChar;
      break;
    default:
      result = UNICODE_TOKEN_NONE;
      break;
    }
  }
  return result;
}

inline static JSONTokenT json_get_prev_token(JSONParserT *parser) {
  JSONTokenT result = UNICODE_TOKEN_NONE;
  json_move_to_prev_char(parser);
  result = json_get_current_token(parser);
  json_move_to_next_char(parser);
  return result;
}

inline static void json_buffer_skip_spaces(JSONParserT *parser) {
  wchar_t currentChar = UNICODE_TABULATION;

  while (json_is_char_space(currentChar)) {
    currentChar = json_current_unicode_char(parser);

    if (json_is_char_space(currentChar)) {
      parser->offset += json_current_char_length(parser);
    }
  }
}

inline static void json_check_skip_colon(JSONParserT *parser) {
  if (json_get_current_token(parser) != UNICODE_TOKEN_COLON) {
    LOG_ERROR("Expected colon after key string!\n");
  } else {
    parser->offset += json_current_char_length(parser);
  }
}

inline static void json_check_skip_comma(JSONParserT *parser) {
  if (json_check_token(parser, UNICODE_TOKEN_COMMA)) {
    parser->offset += json_current_char_length(parser);
  }
}

inline static BOOL json_is_literal_true(JSONTokenT *tokens, size_t tokenCount) {
  BOOL result = TRUE;
  if (tokenCount != 4) {
    result = FALSE;
  } else {
    JSONTokenT trueLiteral[] = {UNICODE_TOKEN_T, UNICODE_TOKEN_R,
                                UNICODE_TOKEN_U, UNICODE_TOKEN_E};
    for (size_t i = 0; ((i < tokenCount) && result); i++) {
      if (tokens[i] != trueLiteral[i]) {
        result = FALSE;
      }
    }
  }
  return result;
}

inline static BOOL json_is_literal_false(JSONTokenT *tokens,
                                         size_t tokenCount) {
  BOOL result = TRUE;
  if (tokenCount != 5) {
    result = FALSE;
  } else {
    JSONTokenT falseLiteral[] = {UNICODE_TOKEN_F, UNICODE_TOKEN_A,
                                 UNICODE_TOKEN_L, UNICODE_TOKEN_S,
                                 UNICODE_TOKEN_E};
    for (size_t i = 0; ((i < tokenCount) && result); i++) {
      if (tokens[i] != falseLiteral[i]) {
        result = FALSE;
      }
    }
  }
  return result;
}

inline static BOOL json_is_literal_null(JSONTokenT *tokens, size_t tokenCount) {
  BOOL result = TRUE;
  if (tokenCount != 3) {
    result = FALSE;
  } else {
    JSONTokenT nullLiteral[] = {UNICODE_TOKEN_N, UNICODE_TOKEN_U,
                                UNICODE_TOKEN_L, UNICODE_TOKEN_L};
    for (size_t i = 0; ((i < tokenCount) && result); i++) {
      if (tokens[i] != nullLiteral[i]) {
        result = FALSE;
      }
    }
  }
  return result;
}

inline static BOOL
json_is_unicode_character(UnicodeCharacterT unicodeCharacter) {
  BOOL result = FALSE;
  if (unicodeCharacter >= UNICODE_LOWERCASE_A &&
      unicodeCharacter <= UNICODE_LOWERCASE_Z) {
    result = TRUE;
  }

  return result;
}

inline static JSONStringT *create_node_string(const int8_t *data,
                                              size_t length) {
  DStringT *dStrResult = str_create(data, length);
  JSONStringT *strJSON = (JSONStringT *)CMALLOC(sizeof(JSONStringT));
  strJSON->valueType = NODE_TYPE_STRING;
  strJSON->value = dStrResult;
  return strJSON;
}

inline static JSONArrayT *create_node_array() {
  JSONArrayT *result = NULL;
  result = (JSONArrayT *)CMALLOC(sizeof(JSONArrayT));
  result->valueType = NODE_TYPE_ARRAY;
  result->elementSize = sizeof(JSONObjectT *);
  result->data = darr_create_generic(result->elementSize);
  return result;
}

inline static JSONObjectObjectElementT *
json_create_json_object_element(JSONStringT *key, JSONObjectT *value) {
  JSONObjectObjectElementT *object =
      (JSONObjectObjectElementT *)CMALLOC(sizeof(JSONObjectObjectElementT));
  object->valueType = NODE_TYPE_OBJECT_ELEMENT;
  object->key = key;
  object->value = value;
  return object;
}

inline static JSONObjectObjectT *json_create_json_object() {
  JSONObjectObjectT *result =
      (JSONObjectObjectT *)CMALLOC(sizeof(JSONObjectObjectT));
  result->valueType = NODE_TYPE_OBJECT;
  result->elements = darr_create_generic(sizeof(JSONObjectObjectElementT *));
  return result;
}

inline static void free_string(JSONStringT *str) {
  str_destroy(str->value);
  CFREE(str, sizeof(JSONStringT *));
}

inline static void free_array(JSONArrayT *arr) {
  for (size_t i = 0; i < darr_length(arr->data); i++) {
    JSONObjectT *element =
        (JSONObjectT *)*(long long *)darr_get_ptr(arr->data, i);
    free_json_tree(element);
  }
  darr_destroy(arr->data);
  CFREE(arr, sizeof(JSONArrayT));
}

inline static void free_object_element(JSONObjectObjectElementT *element) {
  JSONObjectObjectElementT *object = ((JSONObjectObjectElementT *)element);
  free_json_tree((JSONObjectT *)object->key);
  free_json_tree(object->value);
  CFREE(object, sizeof(JSONObjectObjectElementT));
}

inline static void free_object(JSONObjectObjectT *object) {
  DArrayT *elements = object->elements;
  for (size_t i = 0; i < darr_length(elements); i++) {
    JSONObjectT *element =
        (JSONObjectT *)*(long long *)darr_get_ptr(elements, i);
    free_json_tree(element);
  }
  darr_destroy(elements);
  CFREE(object, sizeof(JSONObjecT));
}

inline static void free_json_tree(JSONObjectT *node) {
  if (NULL != node) {
    switch (node->valueType) {
    case NODE_TYPE_OBJECT: {
      free_object((JSONObjectObjectT *)node);
      break;
    }
    case NODE_TYPE_ARRAY:
      free_array((JSONArrayT *)node);
      break;
    case NODE_TYPE_OBJECT_ELEMENT: {
      free_object_element((JSONObjectObjectElementT *)node);
      break;
    }
    case NODE_TYPE_STRING:
      free_string((JSONStringT *)node);
      break;
    }
  }
}

#endif // JSONPARSER_HEADER