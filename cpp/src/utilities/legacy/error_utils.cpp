#include <cudf/cudf.h>

#define GETNAME(x) \
  case x: return #x;

const char* gdf_error_get_name(gdf_error errcode)
{
  switch (errcode) {
    // There must be one entry per enum values in gdf_error.
    GETNAME(GDF_SUCCESS)
    GETNAME(GDF_CUDA_ERROR)
    GETNAME(GDF_UNSUPPORTED_DTYPE)
    GETNAME(GDF_COLUMN_SIZE_MISMATCH)
    GETNAME(GDF_COLUMN_SIZE_TOO_BIG)
    GETNAME(GDF_DATASET_EMPTY)
    GETNAME(GDF_VALIDITY_MISSING)
    GETNAME(GDF_VALIDITY_UNSUPPORTED)
    GETNAME(GDF_INVALID_API_CALL)
    GETNAME(GDF_JOIN_DTYPE_MISMATCH)
    GETNAME(GDF_JOIN_TOO_MANY_COLUMNS)
    GETNAME(GDF_DTYPE_MISMATCH)
    GETNAME(GDF_UNSUPPORTED_METHOD)
    GETNAME(GDF_INVALID_AGGREGATOR)
    GETNAME(GDF_INVALID_HASH_FUNCTION)
    GETNAME(GDF_PARTITION_DTYPE_MISMATCH)
    GETNAME(GDF_HASH_TABLE_INSERT_FAILURE)
    GETNAME(GDF_UNSUPPORTED_JOIN_TYPE)
    GETNAME(GDF_C_ERROR)
    GETNAME(GDF_FILE_ERROR)
    GETNAME(GDF_MEMORYMANAGER_ERROR)
    GETNAME(GDF_UNDEFINED_NVTX_COLOR)
    GETNAME(GDF_NULL_NVTX_NAME)
    GETNAME(GDF_TIMESTAMP_RESOLUTION_MISMATCH)
    GETNAME(GDF_NOTIMPLEMENTED_ERROR)
    GETNAME(GDF_TABLES_SIZE_MISMATCH)
    default:
      // This means we are missing an entry above for a gdf_error value.
      return "Internal error. Unknown error code.";
  }
}