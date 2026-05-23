# Community 145: sleep()

**Members:** 8

## Nodes

- **dev-preflight** (`backend_scripts_dev_preflight_ts`, File, degree: 7)
- **ensureBackendDependencies()** (`backend_scripts_dev_preflight_ts_ensurebackenddependencies`, Function, degree: 2)
- **ensurePostgresWithPodmanRunFallback()** (`backend_scripts_dev_preflight_ts_ensurepostgreswithpodmanrunfallback`, Function, degree: 3)
- **node:fs/existsSync** (`backend_scripts_dev_preflight_ts_import_node_fs_existssync`, Module, degree: 1)
- **run()** (`backend_scripts_dev_preflight_ts_run`, Function, degree: 4)
- **runCapture()** (`backend_scripts_dev_preflight_ts_runcapture`, Function, degree: 2)
- **runDbPush()** (`backend_scripts_dev_preflight_ts_rundbpush`, Function, degree: 2)
- **sleep()** (`backend_scripts_dev_preflight_ts_sleep`, Function, degree: 1)

## Relationships

- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_import_node_fs_existssync (imports)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_run (defines)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_runcapture (defines)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_ensurepostgreswithpodmanrunfallback (defines)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_rundbpush (defines)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_ensurebackenddependencies (defines)
- backend_scripts_dev_preflight_ts → backend_scripts_dev_preflight_ts_sleep (defines)
- backend_scripts_dev_preflight_ts_ensurepostgreswithpodmanrunfallback → backend_scripts_dev_preflight_ts_runcapture (calls)
- backend_scripts_dev_preflight_ts_ensurepostgreswithpodmanrunfallback → backend_scripts_dev_preflight_ts_run (calls)
- backend_scripts_dev_preflight_ts_rundbpush → backend_scripts_dev_preflight_ts_run (calls)
- backend_scripts_dev_preflight_ts_ensurebackenddependencies → backend_scripts_dev_preflight_ts_run (calls)

