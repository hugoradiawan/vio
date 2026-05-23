# Community 200: toProtoCommit()

**Members:** 5

## Nodes

- **checkoutCommit()** (`backend_src_services_commit_ts_checkoutcommit`, Function, degree: 2)
- **cherryPick()** (`backend_src_services_commit_ts_cherrypick`, Function, degree: 2)
- **createCommit()** (`backend_src_services_commit_ts_createcommit`, Function, degree: 2)
- **revertCommit()** (`backend_src_services_commit_ts_revertcommit`, Function, degree: 2)
- **toProtoCommit()** (`backend_src_services_commit_ts_toprotocommit`, Function, degree: 7)

## Relationships

- backend_src_services_commit_ts_createcommit → backend_src_services_commit_ts_toprotocommit (calls)
- backend_src_services_commit_ts_checkoutcommit → backend_src_services_commit_ts_toprotocommit (calls)
- backend_src_services_commit_ts_revertcommit → backend_src_services_commit_ts_toprotocommit (calls)
- backend_src_services_commit_ts_cherrypick → backend_src_services_commit_ts_toprotocommit (calls)

