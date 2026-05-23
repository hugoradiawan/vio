# Community 219: updateColor()

**Members:** 5

## Nodes

- **createColor()** (`backend_src_services_asset_ts_createcolor`, Function, degree: 3)
- **dbGradientToProto()** (`backend_src_services_asset_ts_dbgradienttoproto`, Function, degree: 2)
- **protoGradientToDb()** (`backend_src_services_asset_ts_protogradienttodb`, Function, degree: 3)
- **toProtoColor()** (`backend_src_services_asset_ts_toprotocolor`, Function, degree: 5)
- **updateColor()** (`backend_src_services_asset_ts_updatecolor`, Function, degree: 3)

## Relationships

- backend_src_services_asset_ts_toprotocolor → backend_src_services_asset_ts_dbgradienttoproto (calls)
- backend_src_services_asset_ts_createcolor → backend_src_services_asset_ts_protogradienttodb (calls)
- backend_src_services_asset_ts_createcolor → backend_src_services_asset_ts_toprotocolor (calls)
- backend_src_services_asset_ts_updatecolor → backend_src_services_asset_ts_protogradienttodb (calls)
- backend_src_services_asset_ts_updatecolor → backend_src_services_asset_ts_toprotocolor (calls)

