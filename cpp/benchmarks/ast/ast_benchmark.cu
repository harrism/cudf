/*
 * Copyright (c) 2020, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <benchmark/benchmark.h>

#include <thrust/iterator/counting_iterator.h>

#include <cudf/ast/ast.cuh>
#include <cudf/column/column_factories.hpp>
#include <cudf/table/table.hpp>
#include <cudf/table/table_view.hpp>
#include <cudf/utilities/error.hpp>
#include <tests/utilities/column_wrapper.hpp>

#include <fixture/benchmark_fixture.hpp>
#include <synchronization/synchronization.hpp>

#include <algorithm>
#include <iostream>
#include <list>
#include <numeric>
#include <vector>

enum class TreeType {
  FULL_COMPLETE,   // All operator expressions have two child operator expressions (the last level
                   // has columns)
  IMBALANCED_LEFT  // All operator expressions have a left child operator expression and a right
                   // child column reference
};

template <typename key_type, TreeType tree_type>
class AST : public cudf::benchmark {
};

template <typename key_type, TreeType tree_type>
static void BM_ast_transform(benchmark::State& state)
{
  const cudf::size_type table_size{(cudf::size_type)state.range(0)};
  const cudf::size_type tree_levels = (cudf::size_type)state.range(1);

  // Create table data
  auto n_cols = (tree_type == TreeType::FULL_COMPLETE) ? 2 << tree_levels : tree_levels + 1;
  auto column_wrappers = std::vector<cudf::test::fixed_width_column_wrapper<key_type>>();
  auto columns         = std::vector<cudf::column_view>(n_cols);

  auto data_iterator = thrust::make_counting_iterator(0);
  std::generate_n(std::back_inserter(column_wrappers), n_cols, [=]() {
    return cudf::test::fixed_width_column_wrapper<key_type>(data_iterator,
                                                            data_iterator + table_size);
  });
  std::transform(
    column_wrappers.begin(), column_wrappers.end(), columns.begin(), [](auto const& col) {
      return static_cast<cudf::column_view>(col);
    });

  cudf::table_view table{columns};

  // Create column references
  auto column_refs = std::vector<cudf::ast::column_reference>();
  std::transform(thrust::make_counting_iterator(0),
                 thrust::make_counting_iterator(n_cols),
                 std::back_inserter(column_refs),
                 [](auto const& column_id) { return cudf::ast::column_reference(column_id); });

  // Create expression trees

  // Note that a std::list is required here because of its guarantees against reference invalidation
  // when items are added or removed. References to items in a std::vector are not safe if the
  // vector must re-allocate.
  auto expressions = std::list<cudf::ast::binary_expression>();

  if (tree_type == TreeType::FULL_COMPLETE) {
    // TODO: Construct tree with two child expressions below each expression
  } else {
    // Construct tree that chains additions like (((a + b) + c) + d)
    expressions.push_back(cudf::ast::binary_expression(
      cudf::ast::ast_operator::ADD, column_refs.at(0), column_refs.at(1)));
    // std::cout << "Number of column_refs: " << column_refs.size() << std::endl;
    // std::cout << "Number of expressions: " << expressions.size() << std::endl;
    std::transform(std::next(column_refs.cbegin(), 2),
                   column_refs.cend(),
                   std::back_inserter(expressions),
                   [&](auto const& column_ref) {
                     return cudf::ast::binary_expression(
                       cudf::ast::ast_operator::ADD, expressions.back(), column_ref);
                   });
    // std::cout << "Number of column_refs: " << column_refs.size() << std::endl;
    // std::cout << "Number of expressions: " << expressions.size() << std::endl;
  }

  auto const& expression_tree_root = expressions.back();

  // Execute benchmark
  for (auto _ : state) {
    cuda_event_timer raii(state, true);  // flush_l2_cache = true, stream = 0
    cudf::ast::compute_column(table, expression_tree_root);
  }

  state.SetBytesProcessed(static_cast<int64_t>(state.iterations()) * state.range(0) * n_cols *
                          sizeof(key_type));
}

#define AST_TRANSFORM_BENCHMARK_DEFINE(name, key_type, tree_type) \
  BENCHMARK_TEMPLATE_DEFINE_F(AST, name, key_type, tree_type)     \
  (::benchmark::State & st) { BM_ast_transform<key_type, tree_type>(st); }

AST_TRANSFORM_BENCHMARK_DEFINE(ast_int32_full, int32_t, TreeType::FULL_COMPLETE);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_int64_full, int64_t, TreeType::FULL_COMPLETE);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_float_full, float, TreeType::FULL_COMPLETE);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_double_full, double, TreeType::FULL_COMPLETE);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_int32_imbalanced, int32_t, TreeType::IMBALANCED_LEFT);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_int64_imbalanced, int64_t, TreeType::IMBALANCED_LEFT);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_float_imbalanced, float, TreeType::IMBALANCED_LEFT);
AST_TRANSFORM_BENCHMARK_DEFINE(ast_double_imbalanced, double, TreeType::IMBALANCED_LEFT);

BENCHMARK_REGISTER_F(AST, ast_int32_imbalanced)
  ->Unit(benchmark::kMillisecond)
  ->Args({100'000, 1})
  ->Args({100'000, 10})
  ->Args({100'000, 100})
  ->Args({100'000, 1000})
  ->Args({100'000'000, 1})
  ->Args({100'000'000, 10})
  ->Args({10'000'000, 100})
  ->Args({1'000'000, 1'000})
  ->Args({100'000, 10'000})
  ->UseManualTime();