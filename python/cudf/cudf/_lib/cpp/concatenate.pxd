# Copyright (c) 2020, NVIDIA CORPORATION.

from libcpp.memory cimport unique_ptr
from libcpp.vector cimport vector

from cudf._lib.cpp.column.column cimport column, column_view
from cudf._lib.cpp.table.table cimport table, table_view
from cudf._lib.cpp.utilities.host_span cimport host_span

from rmm._lib.device_buffer cimport device_buffer
    
cdef extern from "cudf/concatenate.hpp" namespace "cudf" nogil:
    cdef device_buffer concatenate_masks "cudf::concatenate_masks"(
        host_span[column_view] views
    ) except +
    cdef unique_ptr[column] concatenate_columns "cudf::concatenate"(
        host_span[column_view] columns
    ) except +
    cdef unique_ptr[table] concatenate_tables "cudf::concatenate"(
        host_span[table_view] tables
    ) except +
