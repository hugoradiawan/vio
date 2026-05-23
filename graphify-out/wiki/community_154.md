# Community 154: toProtoUser()

**Members:** 7

## Nodes

- **generateAccessToken()** (`backend_src_services_auth_ts_generateaccesstoken`, Function, degree: 4)
- **generateRefreshToken()** (`backend_src_services_auth_ts_generaterefreshtoken`, Function, degree: 5)
- **login()** (`backend_src_services_auth_ts_login`, Function, degree: 6)
- **refreshToken()** (`backend_src_services_auth_ts_refreshtoken`, Function, degree: 7)
- **register()** (`backend_src_services_auth_ts_register`, Function, degree: 6)
- **toProtoTimestamp()** (`backend_src_services_auth_ts_toprototimestamp`, Function, degree: 2)
- **toProtoUser()** (`backend_src_services_auth_ts_toprotouser`, Function, degree: 6)

## Relationships

- backend_src_services_auth_ts_toprotouser → backend_src_services_auth_ts_toprototimestamp (calls)
- backend_src_services_auth_ts_register → backend_src_services_auth_ts_toprotouser (calls)
- backend_src_services_auth_ts_register → backend_src_services_auth_ts_refreshtoken (calls)
- backend_src_services_auth_ts_register → backend_src_services_auth_ts_generaterefreshtoken (calls)
- backend_src_services_auth_ts_register → backend_src_services_auth_ts_generateaccesstoken (calls)
- backend_src_services_auth_ts_login → backend_src_services_auth_ts_toprotouser (calls)
- backend_src_services_auth_ts_login → backend_src_services_auth_ts_refreshtoken (calls)
- backend_src_services_auth_ts_login → backend_src_services_auth_ts_generaterefreshtoken (calls)
- backend_src_services_auth_ts_login → backend_src_services_auth_ts_generateaccesstoken (calls)
- backend_src_services_auth_ts_refreshtoken → backend_src_services_auth_ts_toprotouser (calls)
- backend_src_services_auth_ts_refreshtoken → backend_src_services_auth_ts_generaterefreshtoken (calls)
- backend_src_services_auth_ts_refreshtoken → backend_src_services_auth_ts_generateaccesstoken (calls)

