# Community 122: writePerfLog()

**Members:** 9

## Nodes

- **perf-diagnostics** (`backend_src_utils_perf_diagnostics_ts`, File, degree: 8)
- **ensureLogFileReady()** (`backend_src_utils_perf_diagnostics_ts_ensurelogfileready`, Function, degree: 2)
- **getPerfDiagnosticsConfig()** (`backend_src_utils_perf_diagnostics_ts_getperfdiagnosticsconfig`, Function, degree: 1)
- **node:fs/promises/appendFile** (`backend_src_utils_perf_diagnostics_ts_import_node_fs_promises_appendfile`, Module, degree: 1)
- **node:fs/promises/mkdir** (`backend_src_utils_perf_diagnostics_ts_import_node_fs_promises_mkdir`, Module, degree: 1)
- **node:path/path** (`backend_src_utils_perf_diagnostics_ts_import_node_path_path`, Module, degree: 1)
- **serializeError()** (`backend_src_utils_perf_diagnostics_ts_serializeerror`, Function, degree: 2)
- **startPerfSpan()** (`backend_src_utils_perf_diagnostics_ts_startperfspan`, Function, degree: 3)
- **writePerfLog()** (`backend_src_utils_perf_diagnostics_ts_writeperflog`, Function, degree: 3)

## Relationships

- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_import_node_fs_promises_appendfile (imports)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_import_node_fs_promises_mkdir (imports)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_import_node_path_path (imports)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_serializeerror (defines)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_ensurelogfileready (defines)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_writeperflog (defines)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_startperfspan (defines)
- backend_src_utils_perf_diagnostics_ts → backend_src_utils_perf_diagnostics_ts_getperfdiagnosticsconfig (defines)
- backend_src_utils_perf_diagnostics_ts_writeperflog → backend_src_utils_perf_diagnostics_ts_ensurelogfileready (calls)
- backend_src_utils_perf_diagnostics_ts_startperfspan → backend_src_utils_perf_diagnostics_ts_serializeerror (calls)
- backend_src_utils_perf_diagnostics_ts_startperfspan → backend_src_utils_perf_diagnostics_ts_writeperflog (calls)

