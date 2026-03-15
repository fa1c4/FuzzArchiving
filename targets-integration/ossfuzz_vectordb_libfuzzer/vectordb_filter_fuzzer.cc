// vectordb_filter_fuzzer.cc
#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

#include "query/expr/expr.hpp"
#include "query/expr/expr_types.hpp"
#include "utils/status.hpp"
#include "utils/json.hpp"

using vectordb::Status;
using vectordb::query::expr::Expr;
using vectordb::query::expr::ExprNodePtr;

static std::unordered_map<std::string, vectordb::engine::meta::FieldType> &
GetFieldMap() {
  // Construct a simple fixed field map; type names are derived directly from switches in expr.cpp
  using FT = vectordb::engine::meta::FieldType;
  static bool initialized = false;
  static std::unordered_map<std::string, FT> field_map;

  if (!initialized) {
    // These field names are examples intended to cover different FieldType branches
    field_map["ID1"] = FT::INT1;
    field_map["ID2"] = FT::INT2;
    field_map["ID4"] = FT::INT4;
    field_map["ID8"] = FT::INT8;
    field_map["Score"] = FT::DOUBLE;
    field_map["ScoreF"] = FT::FLOAT;
    field_map["Flag"] = FT::BOOL;
    field_map["Doc"] = FT::STRING;
    field_map["Geo"] = FT::GEO_POINT;
    field_map["@distance"] = FT::DOUBLE;  // Corresponds to the isDistance branch

    initialized = true;
  }
  return field_map;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) {
    return 0;
  }

  // Treat fuzz data as a filter expression string
  std::string expr_str(reinterpret_cast<const char *>(data), size);

  auto &field_map = GetFieldMap();
  std::vector<ExprNodePtr> nodes;

  Expr expr;
  Status st =
      expr.ParseNodeFromStr(expr_str, nodes, field_map,
                            /*check_bool =*/false);

  if (!st.ok()) {
    // Return immediately on parsing failure; INVALID_EXPR / NOT_IMPLEMENTED are expected behaviors
    return 0;
  }

  // After successful parsing, Dump each node to JSON to increase code coverage
  for (auto &node : nodes) {
    if (!node) {
      continue;
    }
    vectordb::Json json;               // ⭐ Updated to use vectordb::Json
    expr.DumpToJson(node, json);
  }

  return 0;
}
