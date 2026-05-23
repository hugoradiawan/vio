# 📊 Graph Analysis Report

**Root:** `.`

## Summary

| Metric | Value |
|--------|-------|
| Nodes | 3871 |
| Edges | 5049 |
| Communities | 384 |
| Hyperedges | 0 |

### Confidence Breakdown

| Level | Count | Percentage |
|-------|-------|------------|
| EXTRACTED | 3413 | 67.6% |
| INFERRED | 1636 | 32.4% |
| AMBIGUOUS | 0 | 0.0% |

## 🌟 God Nodes (Most Connected)

| Node | Degree | Community |
|------|--------|-----------|
| frb_generated.web | 194 | 0 |
| frb_generated.io | 193 | 1 |
| canvas | 74 | 2 |
| asset | 63 | 6 |
| generate | 62 | 5 |
| pullrequest | 61 | 4 |
| canvas.pb | 57 | 3 |
| shape | 55 | 7 |
| RustLib() | 51 | 23 |
| branch | 49 | 8 |

## 🔮 Surprising Connections

- **backend_src_services_canvas_ts_processoperation** → **backend_src_services_canvas_ts_toprotoshape** (calls)
- **backend_src_services_shape_ts_toprotoshape** → **backend_src_services_shape_ts_dbtofill** (calls)
- **backend_src_services_shape_ts_createshape** → **backend_src_services_shape_ts_toprotoshape** (calls)
- **backend_src_services_shape_ts_batchmutate** → **backend_src_services_shape_ts_toprotoshape** (calls)
- **backend_src_services_commit_ts_toprotocommit** → **backend_src_services_commit_ts_toprototimestamp** (calls)

## 🏘️ Communities

### Community 0 — wire() (0) (195 nodes, cohesion: 0.01)

- frb_generated.web
- dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_blur_type()
- dco_decode_bool()
- dco_decode_bool_op()
- dco_decode_box_autoadd_gradient_data()
- dco_decode_box_autoadd_shape_blur()
- dco_decode_box_autoadd_shape_gradient()
- dco_decode_box_autoadd_shape_shadow()
- dco_decode_box_autoadd_stroke_data()
- dco_decode_draw_command()
- dco_decode_f_64()
- dco_decode_f_64_array_2()
- dco_decode_f_64_array_4()
- dco_decode_f_64_array_6()
- dco_decode_gradient_data()
- dco_decode_gradient_stop()
- dco_decode_gradient_type()
- _…and 175 more_

### Community 1 — wire() (194 nodes, cohesion: 0.01)

- frb_generated.io
- dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_Auto_RefMut_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- dco_decode_blur_type()
- dco_decode_bool()
- dco_decode_bool_op()
- dco_decode_box_autoadd_gradient_data()
- dco_decode_box_autoadd_shape_blur()
- dco_decode_box_autoadd_shape_gradient()
- dco_decode_box_autoadd_shape_shadow()
- dco_decode_box_autoadd_stroke_data()
- dco_decode_draw_command()
- dco_decode_f_64()
- dco_decode_f_64_array_2()
- dco_decode_f_64_array_4()
- dco_decode_f_64_array_6()
- dco_decode_gradient_data()
- dco_decode_gradient_stop()
- dco_decode_gradient_type()
- _…and 174 more_

### Community 2 — syncChanges() (70 nodes, cohesion: 0.03)

- canvas
- broadcastUpdate()
- clearWorkingCopy()
- collaborate()
- dbToFill()
- dbToGradient()
- fillToDb()
- getChannelKey()
- gradientTypeToString()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/db
- ../db/schema
- drizzle-orm/and
- drizzle-orm/asc
- drizzle-orm/eq
- ./errors.js/invalidArgument
- ./errors.js/notFound
- ../gen/vio/v1/canvas_pb.js/CanvasService
- ../gen/vio/v1/canvas_pb.js/CanvasStateSchema
- _…and 50 more_

### Community 3 — UserPresence() (58 nodes, cohesion: 0.03)

- canvas.pb
- CanvasState()
- CanvasUpdate()
- CanvasUpdate_Update
- _CanvasUpdate_UpdateByTag()
- $_clearField()
- ClearWorkingCopyRequest()
- ClearWorkingCopyResponse()
- CollaborateRequest()
- CollaborateRequest_Request
- _CollaborateRequest_RequestByTag()
- CollaborateResponse()
- CollaborateResponse_Response
- _CollaborateResponse_ResponseByTag()
- create()
- CursorMoved()
- CursorPosition()
- deepCopy()
- $_ensure()
- $_getBF()
- _…and 38 more_

### Community 4 — toProtoTimestamp() (55 nodes, cohesion: 0.04)

- pullrequest
- checkMergeStatus()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/db
- ../db/schema
- drizzle-orm/and
- drizzle-orm/desc
- drizzle-orm/eq
- ./errors.js/alreadyExists
- ./errors.js/failedPrecondition
- ./errors.js/internal
- ./errors.js/invalidArgument
- ./errors.js/notFound
- ../gen/vio/v1/branch_pb.js/Branch
- ../gen/vio/v1/branch_pb.js/BranchSchema
- ../gen/vio/v1/commit_pb.js/Commit
- ../gen/vio/v1/commit_pb.js/CommitSchema
- ../gen/vio/v1/common_pb.js/Timestamp
- ../gen/vio/v1/common_pb.js/TimestampSchema
- _…and 35 more_

### Community 5 — zero_opacity_shape_skipped() (54 nodes, cohesion: 0.12)

- generate
- clipping_frame_emits_clip_and_restore()
- drop_shadow_emitted()
- ellipse_emits_draw_oval()
- emit_background_blur()
- emit_drop_shadow()
- emit_general_commands()
- emit_image_commands()
- emit_inner_shadow()
- emit_shape_commands()
- emit_shape_tree()
- emit_stroke()
- empty_scene_generates_view_transform_only()
- engine_load_and_generate_integration()
- frame_with_children_emits_commands_for_all()
- generate_draw_commands()
- generate_draw_commands_excluding()
- generate_draw_commands_impl()
- gradient_fill_emits_gradient_command()
- hidden_fill_skipped()
- _…and 34 more_

### Community 6 — withDbTimeout() (53 nodes, cohesion: 0.04)

- asset
- deleteAsset()
- deleteColor()
- getAsset()
- @bufbuild/protobuf/create
- @connectrpc/connect/Code
- @connectrpc/connect/ConnectError
- @connectrpc/connect/ServiceImpl
- ../db/index.js/db
- ../db/schema/index.js/projectAssets
- ../db/schema/index.js/projectColors
- drizzle-orm/and
- drizzle-orm/eq
- drizzle-orm/like
- ./errors.js/notFound
- ./errors.js/unavailable
- ../gen/vio/v1/asset_pb.js/Asset
- ../gen/vio/v1/asset_pb.js/AssetSchema
- ../gen/vio/v1/asset_pb.js/AssetService
- ../gen/vio/v1/asset_pb.js/CreateColorRequest
- _…and 33 more_

### Community 7 — stringToGradientType() (51 nodes, cohesion: 0.04)

- shape
- batchMutate()
- createShape()
- dbToFill()
- dbToGradient()
- deleteShape()
- fillToDb()
- gradientTypeToString()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/index.js/db
- ../db/schema/index.js/shapes
- drizzle-orm/and
- drizzle-orm/eq
- ./errors.js/notFound
- ../gen/vio/v1/common_pb.js/Empty
- ../gen/vio/v1/common_pb.js/EmptySchema
- ../gen/vio/v1/common_pb.js/Fill
- ../gen/vio/v1/common_pb.js/FillSchema
- ../gen/vio/v1/common_pb.js/Gradient
- _…and 31 more_

### Community 8 — updateBranch() (50 nodes, cohesion: 0.05)

- branch
- compareBranches()
- createBranch()
- deleteBranch()
- getBranch()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/db
- ../db/schema
- drizzle-orm/and
- drizzle-orm/eq
- ./errors.js/alreadyExists
- ./errors.js/failedPrecondition
- ./errors.js/internal
- ./errors.js/notFound
- ../gen/vio/v1/branch_pb.js/Branch
- ../gen/vio/v1/branch_pb.js/BranchSchema
- ../gen/vio/v1/branch_pb.js/BranchService
- ../gen/vio/v1/branch_pb.js/CompareBranchesResponse
- ../gen/vio/v1/branch_pb.js/CompareBranchesResponseSchema
- _…and 30 more_

### Community 9 — .sse_decode() (9) (45 nodes, cohesion: 0.04)

- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- .sse_decode()
- _…and 25 more_

### Community 10 — .sse_encode() (10) (45 nodes, cohesion: 0.04)

- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- .sse_encode()
- _…and 25 more_

### Community 11 — toProtoTimestamp() (11) (44 nodes, cohesion: 0.05)

- commit
- getCommit()
- getDiff()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/db
- ../db/schema
- drizzle-orm/and
- drizzle-orm/asc
- drizzle-orm/desc
- drizzle-orm/eq
- ./errors.js/failedPrecondition
- ./errors.js/internal
- ./errors.js/notFound
- ../gen/vio/v1/commit_pb.js/CheckoutCommitResponse
- ../gen/vio/v1/commit_pb.js/CheckoutCommitResponseSchema
- ../gen/vio/v1/commit_pb.js/CherryPickResponse
- ../gen/vio/v1/commit_pb.js/CherryPickResponseSchema
- ../gen/vio/v1/commit_pb.js/Commit
- ../gen/vio/v1/commit_pb.js/CommitSchema
- _…and 24 more_

### Community 12 — Transform() (42 nodes, cohesion: 0.05)

- common.pb
- BoolProperties()
- $_clearField()
- ConflictResolution()
- create()
- deepCopy()
- Empty()
- $_ensure()
- Fill()
- FillImage()
- FrameProperties()
- $_getBF()
- $_getI64()
- $_getIZ()
- $_getList()
- $_getN()
- $_getSZ()
- Gradient()
- GradientStop()
- $_has()
- _…and 22 more_

### Community 13 — UpdatePullRequestResponse() (40 nodes, cohesion: 0.05)

- pullrequest.pb
- CheckMergeStatusRequest()
- CheckMergeStatusResponse()
- $_clearField()
- ClosePullRequestRequest()
- ClosePullRequestResponse()
- create()
- CreatePullRequestRequest()
- CreatePullRequestResponse()
- deepCopy()
- $_ensure()
- $_getBF()
- $_getIZ()
- $_getList()
- $_getN()
- GetPullRequestRequest()
- GetPullRequestResponse()
- $_getSZ()
- $_has()
- _i()
- _…and 20 more_

### Community 14 — WorkerPool (40 nodes, cohesion: 0.11)

- rust_lib_vio_client
- addHeapObject()
- debugString()
- dropObject()
- frb_dart_fn_deliver_output()
- frb_dart_opaque_dart2rust_encode()
- frb_dart_opaque_drop_thread_box_persistent_handle()
- frb_dart_opaque_rust2dart_decode()
- frb_get_rust_content_hash()
- frb_pde_ffi_dispatcher_primary()
- frb_pde_ffi_dispatcher_sync()
- getFloat64Memory0()
- getInt32Memory0()
- getObject()
- getStringFromWasm0()
- getUint32Memory0()
- getUint8Memory0()
- handleError()
- initSync()
- isLikeNone()
- _…and 20 more_

### Community 15 — UploadAssetResponse() (37 nodes, cohesion: 0.05)

- asset.pb
- Asset()
- $_clearField()
- create()
- CreateColorRequest()
- CreateColorResponse()
- deepCopy()
- DeleteAssetRequest()
- DeleteColorRequest()
- $_ensure()
- GetAssetRequest()
- GetAssetResponse()
- $_getIZ()
- $_getList()
- $_getN()
- $_getSZ()
- $_has()
- _i()
- common.pb.dart'
- dart:core'
- _…and 17 more_

### Community 16 — updateProject() (16) (35 nodes, cohesion: 0.07)

- project
- createProject()
- deleteProject()
- getProject()
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/db
- ../db/schema
- drizzle-orm/eq
- ./errors.js/notFound
- ../gen/vio/v1/branch_pb.js/Branch
- ../gen/vio/v1/branch_pb.js/BranchSchema
- ../gen/vio/v1/common_pb.js/Empty
- ../gen/vio/v1/common_pb.js/EmptySchema
- ../gen/vio/v1/common_pb.js/Timestamp
- ../gen/vio/v1/common_pb.js/TimestampSchema
- ../gen/vio/v1/project_pb.js/CreateProjectResponse
- ../gen/vio/v1/project_pb.js/CreateProjectResponseSchema
- ../gen/vio/v1/project_pb.js/Frame
- ../gen/vio/v1/project_pb.js/FrameSchema
- _…and 15 more_

### Community 17 — UpdateShapeResponse() (34 nodes, cohesion: 0.06)

- shape.pb
- BatchMutateRequest()
- BatchMutateResponse()
- $_clearField()
- create()
- CreateShapeRequest()
- CreateShapeResponse()
- deepCopy()
- DeleteShapeRequest()
- $_ensure()
- $_getBF()
- $_getIZ()
- $_getList()
- $_getN()
- GetShapeRequest()
- GetShapeResponse()
- $_getSZ()
- $_has()
- _i()
- common.pb.dart'
- _…and 14 more_

### Community 18 — Snapshot() (34 nodes, cohesion: 0.06)

- commit.pb
- CheckoutCommitRequest()
- CheckoutCommitResponse()
- CherryPickRequest()
- CherryPickResponse()
- $_clearField()
- Commit()
- CommitSummary()
- create()
- CreateCommitRequest()
- CreateCommitResponse()
- deepCopy()
- DiffResult()
- $_ensure()
- GetCommitRequest()
- GetCommitResponse()
- GetDiffRequest()
- GetDiffResponse()
- $_getList()
- $_getN()
- _…and 14 more_

### Community 19 — UpdateBranchResponse() (34 nodes, cohesion: 0.06)

- branch.pb
- Branch()
- $_clearField()
- CompareBranchesRequest()
- CompareBranchesResponse()
- create()
- CreateBranchRequest()
- CreateBranchResponse()
- deepCopy()
- DeleteBranchRequest()
- $_ensure()
- $_getBF()
- GetBranchRequest()
- GetBranchResponse()
- $_getIZ()
- $_getList()
- $_getN()
- $_getSZ()
- $_has()
- _i()
- _…and 14 more_

### Community 20 — update_existing_shape() (34 nodes, cohesion: 0.17)

- tree
- children_of_container()
- children_of_nonexistent_container()
- depth_first_order()
- empty_tree()
- frame_children_via_frame_id()
- crate::math::matrix2d::Matrix2D
- crate::scene_graph::shape::*
- crate::scene_graph::shape::RenderShape
- std::collections::HashMap
- super::*
- insert_and_get()
- make_child()
- make_shape()
- remove_child_from_parent()
- remove_shape()
- root_shapes()
- SceneTree
- .all_shapes()
- .children_of()
- _…and 14 more_

### Community 21 — translation_moves_point() (34 nodes, cohesion: 0.16)

- matrix2d
- assert_near()
- default_is_identity()
- determinant_of_identity_is_one()
- determinant_of_scale()
- identity_transform_preserves_point()
- super::*
- invert_identity_is_identity()
- invert_singular_returns_none()
- Matrix2D
- .default()
- .determinant()
- .from_array()
- .identity()
- .invert()
- .multiply()
- .new()
- .rotation()
- .rotation_at()
- .scale()
- _…and 14 more_

### Community 22 — update_shape_position() (33 nodes, cohesion: 0.16)

- spatial_index
- build_from_shapes()
- empty_index()
- hidden_shapes_not_indexed()
- crate::math::matrix2d::Matrix2D
- crate::scene_graph::shape::*
- crate::scene_graph::shape::RenderShape
- rstar::{RTree, RTreeObject, AABB}
- super::*
- insert_and_query()
- large_number_of_shapes()
- make_shape_at()
- query_point_finds_containing()
- query_visible_empty_viewport()
- query_visible_finds_overlapping()
- remove_nonexistent_returns_false()
- remove_shape()
- ShapeEnvelope
- .envelope()
- .eq()
- _…and 13 more_

### Community 23 — wire() (23) (32 nodes, cohesion: 0.85)

- frb_generated
- crateApiEngineCanvasEngineCreate()
- crateApiEngineCanvasEngineGenerateDrawCommands()
- crateApiEngineCanvasEngineHitTestPoint()
- crateApiEngineCanvasEngineHitTestRect()
- crateApiEngineCanvasEngineLoadAllShapes()
- crateApiEngineCanvasEngineMarkAllTilesDirty()
- crateApiEngineCanvasEnginePaintOrder()
- crateApiEngineCanvasEngineQueryVisible()
- crateApiEngineCanvasEngineRasterizeDirtyTiles()
- crateApiEngineCanvasEngineShapeCount()
- crateApiEngineCanvasEngineSyncShapes()
- crateApiEngineCanvasEngineTileCacheStats()
- crateApiEngineCanvasEngineTileRasterizedCount()
- crateApiSimpleGreet()
- crateApiSimpleInitApp()
- api/engine.dart
- api/simple.dart
- dart:async
- dart:convert
- _…and 12 more_

### Community 24 — UpdateProjectResponse() (32 nodes, cohesion: 0.06)

- project.pb
- $_clearField()
- create()
- CreateProjectRequest()
- CreateProjectResponse()
- deepCopy()
- DeleteProjectRequest()
- $_ensure()
- Frame()
- $_getBF()
- $_getIZ()
- $_getList()
- $_getN()
- GetProjectRequest()
- GetProjectResponse()
- $_getSZ()
- $_has()
- _i()
- branch.pb.dart'
- common.pb.dart'
- _…and 12 more_

### Community 25 — ./utils/perf-diagnostics.js/getPerfDiagnosticsConfig (29 nodes, cohesion: 0.07)

- index
- @connectrpc/connect/ConnectRouter
- @connectrpc/connect-node/connectNodeAdapter
- ./gen/vio/v1/asset_pb.js/AssetService
- ./gen/vio/v1/auth_pb.js/AuthService
- ./gen/vio/v1/branch_pb.js/BranchService
- ./gen/vio/v1/canvas_pb.js/CanvasService
- ./gen/vio/v1/commit_pb.js/CommitService
- ./gen/vio/v1/project_pb.js/ProjectService
- ./gen/vio/v1/pullrequest_pb.js/PullRequestService
- ./gen/vio/v1/shape_pb.js/ShapeService
- ./interceptors/index.js/authInterceptor
- ./interceptors/index.js/loggingInterceptor
- node:fs/readFileSync
- node:http2/createSecureServer
- node:http2/createServer
- node:path/dirname
- node:path/join
- node:url/fileURLToPath
- ./services/index.js/assetServiceImpl
- _…and 9 more_

### Community 26 — value() (26) (28 nodes, cohesion: 0.07)

- commands.freezed
- call()
- _$DrawCommand
- _$DrawCommand_BeginShapeCopyWithImpl()
- _$DrawCommand_ClipOvalCopyWithImpl()
- _$DrawCommand_ClipRectCopyWithImpl()
- _$DrawCommand_ClipRRectCopyWithImpl()
- _$DrawCommand_DrawImageCopyWithImpl()
- _$DrawCommand_DrawOvalCopyWithImpl()
- _$DrawCommand_DrawOvalGradientCopyWithImpl()
- _$DrawCommand_DrawOvalStrokeCopyWithImpl()
- _$DrawCommand_DrawPathCopyWithImpl()
- _$DrawCommand_DrawRectCopyWithImpl()
- _$DrawCommand_DrawRRectCopyWithImpl()
- _$DrawCommand_DrawRRectGradientCopyWithImpl()
- _$DrawCommand_DrawRRectStrokeCopyWithImpl()
- _$DrawCommand_DrawShadowCopyWithImpl()
- _$DrawCommand_DrawTextCopyWithImpl()
- _$DrawCommand_PushBlurCopyWithImpl()
- _$DrawCommand_PushTransformCopyWithImpl()
- _…and 8 more_

### Community 27 — ValidateTokenResponse() (27 nodes, cohesion: 0.07)

- auth.pb
- AuthResponse()
- $_clearField()
- create()
- deepCopy()
- $_ensure()
- $_getBF()
- $_getI64()
- $_getN()
- $_getSZ()
- $_has()
- _i()
- common.pb.dart'
- dart:core'
- package:fixnum/fixnum.dart'
- package:protobuf/protobuf.dart'
- LoginRequest()
- LogoutRequest()
- RefreshTokenRequest()
- RegisterRequest()
- _…and 7 more_

### Community 28 — toProtoTimestamp() (28) (26 nodes, cohesion: 0.10)

- merge
- buildShapeMap()
- calculateDiff()
- canFastForward()
- compareProperty()
- countCommitsDivergence()
- createMergeCommit()
- findCommonAncestor()
- getSnapshotData()
- @bufbuild/protobuf/create
- ../db/db
- ../db/schema
- drizzle-orm/eq
- ../gen/vio/v1/commit_pb.js/DiffResult
- ../gen/vio/v1/commit_pb.js/DiffResultSchema
- ../gen/vio/v1/common_pb.js/PropertyConflict
- ../gen/vio/v1/common_pb.js/PropertyConflictSchema
- ../gen/vio/v1/common_pb.js/ShapeConflict
- ../gen/vio/v1/common_pb.js/ShapeConflictSchema
- ../gen/vio/v1/common_pb.js/Timestamp
- _…and 6 more_

### Community 29 — getDurationMsFromEnv() (25 nodes, cohesion: 0.08)

- auth
- getDurationMsFromEnv()
- bcryptjs/bcrypt
- @bufbuild/protobuf/create
- @connectrpc/connect/ServiceImpl
- ../db/index.js/db
- ../db/index.js/schema
- drizzle-orm/eq
- ./errors.js/alreadyExists
- ./errors.js/invalidArgument
- ./errors.js/notFound
- ./errors.js/unauthenticated
- ./errors.js/unavailable
- ../gen/vio/v1/auth_pb.js/AuthResponse
- ../gen/vio/v1/auth_pb.js/AuthResponseSchema
- ../gen/vio/v1/auth_pb.js/AuthService
- ../gen/vio/v1/auth_pb.js/User
- ../gen/vio/v1/auth_pb.js/UserSchema
- ../gen/vio/v1/auth_pb.js/ValidateTokenResponse
- ../gen/vio/v1/auth_pb.js/ValidateTokenResponseSchema
- _…and 5 more_

### Community 30 — .into_dart() (24 nodes, cohesion: 0.13)

- .into_dart()
- .into_into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- .into_dart()
- _…and 4 more_

### Community 31 — _CanvasViewState() (24 nodes, cohesion: 0.08)

- canvas_view
- _CanvasContextAction
- _CanvasViewState()
- canvas_performance_diagnostics.dart
- canvas_view_controller.dart
- dart:async
- package:desktop_drop/desktop_drop.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/foundation.dart
- package:flutter/gestures.dart
- package:flutter/material.dart
- package:flutter/services.dart
- package:google_fonts/google_fonts.dart
- package:uuid/uuid.dart
- package:vio_client/src/core/core.dart
- package:vio_client/src/features/assets/bloc/asset_bloc.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/features/canvas/models/frame_presets.dart
- package:vio_client/src/features/workspace/bloc/workspace_bloc.dart
- package:vio_core/vio_core.dart
- _…and 4 more_

### Community 32 — toJson() (24 nodes, cohesion: 0.08)

- shape
- BlurType
- bounds()
- ConstraintType
- copyWith()
- GradientStop()
- GradientType
- package:equatable/equatable.dart
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- moveBy()
- ShadowStyle
- ShapeBlur()
- ShapeConstraints()
- ShapeFill()
- ShapeFillImage()
- ShapeGradient()
- ShapeShadow()
- ShapeStroke()
- ShapeType
- _…and 4 more_

### Community 33 — src/utils/snap.dart (24 nodes, cohesion: 0.08)

- vio_core
- src/extensions/num_extensions.dart
- src/extensions/offset_extensions.dart
- src/extensions/rect_extensions.dart
- src/math/math_utils.dart
- src/math/matrix2d.dart
- src/models/bool_shape.dart
- src/models/ellipse_shape.dart
- src/models/frame_shape.dart
- src/models/group_shape.dart
- src/models/image_shape.dart
- src/models/path_shape.dart
- src/models/project_asset.dart
- src/models/rectangle_shape.dart
- src/models/result.dart
- src/models/shape.dart
- src/models/shape_factory.dart
- src/models/svg_shape.dart
- src/models/text_shape.dart
- src/models/uuid_value.dart
- _…and 4 more_

### Community 34 — WndProc() (24 nodes, cohesion: 1.38)

- win32_window
- Create()
- Destroy()
- GetClientArea()
- GetHandle()
- GetThisFromHandle()
- GetWindowClass()
- dwmapi.h
- flutter_windows.h
- resource.h
- win32_window.h
- MessageHandler()
- OnCreate()
- OnDestroy()
- SetChildContent()
- SetQuitOnClose()
- Show()
- UnregisterWindowClass()
- UpdateTheme()
- Win32Window()
- _…and 4 more_

### Community 35 — update_shape_moves_tiles() (23 nodes, cohesion: 0.15)

- dirty_tracking()
- evict_distant_tiles()
- mark_all_dirty()
- register_and_unregister_shape()
- tile_world_size_at_zoom_2()
- TileGrid
- .clear()
- .dirty_tile_count()
- .dirty_tiles_in_viewport()
- .get_tile_pixels()
- .get_tile_pixels_any()
- .keys_for_aabb()
- .mark_all_dirty()
- .mark_shape_dirty()
- .register_shape()
- .set_zoom()
- .shapes_for_tile()
- .store_tile()
- .tile_world_bounds()
- .tile_world_size()
- _…and 3 more_

### Community 36 — width_and_height() (22 nodes, cohesion: 0.16)

- aabb
- .empty()
- .from_xywh()
- .height()
- .intersection()
- .is_empty()
- .overlaps()
- .width()
- contains_fully_inside()
- contains_point_inside()
- empty_aabb_is_empty()
- from_xywh_correctness()
- super::*
- inflate_expands()
- intersection_disjoint_is_none()
- intersection_overlapping()
- normal_aabb_is_not_empty()
- overlaps_edge_touching_is_false()
- overlaps_false()
- overlaps_true()
- _…and 2 more_

### Community 37 — package:vio_core/vio_core.dart (22 nodes, cohesion: 0.09)

- canvas_bloc
- canvas_bloc_commands.dart
- canvas_bloc_hierarchy.dart
- canvas_bloc_history.dart
- canvas_bloc_interaction.dart
- canvas_bloc_rust.dart
- canvas_bloc_sync.dart
- canvas_bloc_text.dart
- canvas_bloc_viewport.dart
- canvas_event.dart
- canvas_state.dart
- ../../../core/core.dart
- dart:async
- dart:math'
- ../models/handle_types.dart
- ../models/selection_handle_metrics.dart
- ../models/selection_hit_test.dart
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/rendering.dart
- _…and 2 more_

### Community 38 — ShapeStroke (22 nodes, cohesion: 0.10)

- shape
- BlurType
- BoolOp
- geometry_dimensions()
- GradientStop
- GradientType
- crate::math::matrix2d::Matrix2D
- super::*
- ShadowStyle
- shape_type_equality()
- ShapeBlur
- ShapeFill
- ShapeGeometry
- .dimensions()
- ShapeGradient
- ShapeShadow
- ShapeStroke
- ShapeType
- StrokeAlignment
- StrokeCap
- _…and 2 more_

### Community 39 — set_paint_color() (21 nodes, cohesion: 0.15)

- painter
- argb_to_color()
- argb_to_color_opaque_red()
- argb_to_color_with_opacity()
- build_gradient_shader()
- build_rounded_rect_path()
- build_rounded_rect_path_works()
- build_shape_path()
- crate::math::aabb::Aabb
- crate::math::matrix2d::Matrix2D
- crate::rasterizer::tiles::TILE_SIZE
- crate::scene_graph::shape::*
- crate::scene_graph::tree::SceneTree
- super::*
- tiny_skia::{
    Color, FillRule, LineCap, LineJoin, LinearGradient, Paint, Path, PathBuilder, Pixmap, Point,
    RadialGradient, Rect, Shader, SpreadMode, Stroke, Transform,
}
- is_rasterizable_ellipse()
- make_ellipse()
- matrix2d_to_transform()
- paint_shape()
- rasterize_ellipse()
- _…and 1 more_

### Community 40 — ServiceLocator() (21 nodes, cohesion: 0.10)

- version_control_bloc
- ../../../core/core.dart
- dart:async
- dart:convert
- ../../../gen/vio/v1/branch.pb.dart'
- ../../../gen/vio/v1/branch.pbgrpc.dart
- ../../../gen/vio/v1/commit.pb.dart'
- ../../../gen/vio/v1/commit.pbgrpc.dart
- ../../../gen/vio/v1/common.pb.dart'
- ../../../gen/vio/v1/common.pbenum.dart'
- ../../../gen/vio/v1/pullrequest.pb.dart'
- ../../../gen/vio/v1/pullrequest.pbenum.dart'
- ../../../gen/vio/v1/pullrequest.pbgrpc.dart'
- ../models/models.dart
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:grpc/grpc.dart
- package:vio_core/vio_core.dart
- version_control_event.dart
- version_control_state.dart
- _…and 1 more_

### Community 41 — ../viewport_notifier.dart (20 nodes, cohesion: 0.10)

- canvas_surface
- canvas_status_widgets.dart
- canvas_text_editor_overlay.dart
- ../../../../core/services/rust_engine_service.dart
- package:flutter/foundation.dart
- package:flutter/material.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/features/canvas/presentation/painters/canvas_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/grid_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/horizontal_ruler_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/selection_box_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/size_indicator_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/snap_guides_painter.dart
- package:vio_client/src/features/canvas/presentation/painters/vertical_ruler_painter.dart
- package:vio_client/src/features/workspace/bloc/workspace_bloc.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- rust_canvas_layer.dart
- tile_compositor_layer.dart
- ../viewport_notifier.dart

### Community 42 — tileRasterizedCount() (20 nodes, cohesion: 0.10)

- engine
- generateDrawCommands()
- hitTestPoint()
- hitTestRect()
- ../frb_generated.dart
- ../lib.dart
- ../math/matrix2d.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart
- ../render/commands.dart
- ../scene_graph/shape.dart
- loadAllShapes()
- markAllTilesDirty()
- paintOrder()
- queryVisible()
- rasterizeDirtyTiles()
- RustLib()
- shapeCount()
- syncShapes()
- tileCacheStats()
- tileRasterizedCount()

### Community 43 — runMain() (43) (19 nodes, cohesion: 0.11)

- build_tool
- android_environment.dart
- build_cmake.dart
- build_gradle.dart
- build_pod.dart
- dart:io
- logging.dart
- options.dart
- package:args/command_runner.dart
- package:ed25519_edwards/ed25519_edwards.dart
- package:github/github.dart
- package:hex/hex.dart
- package:logging/logging.dart
- precompile_binaries.dart
- target.dart
- util.dart
- verify_binaries.dart
- runBuildCommand()
- runMain()

### Community 44 — ./common_pb.js/Timestamp (44) (19 nodes, cohesion: 0.11)

- pullrequest_pb
- @bufbuild/protobuf/codegenv2/enumDesc
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenEnum
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./commit_pb.js/Commit
- ./commit_pb.js/DiffResult
- ./commit_pb.js/file_vio_v1_commit
- ./common_pb.js/ConflictResolution
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/MergeStrategy
- ./common_pb.js/PageToken
- ./common_pb.js/ShapeConflict
- ./common_pb.js/Timestamp

### Community 45 — value() (45) (19 nodes, cohesion: 0.11)

- shape.freezed
- call()
- _$identity()
- shape.dart
- Object()
- _$ShapeGeometry
- _$ShapeGeometry_BoolCopyWithImpl()
- _$ShapeGeometry_EllipseCopyWithImpl()
- _$ShapeGeometry_FrameCopyWithImpl()
- _$ShapeGeometry_GroupCopyWithImpl()
- _$ShapeGeometry_ImageCopyWithImpl()
- .Object()
- _$ShapeGeometry_PathCopyWithImpl()
- _$ShapeGeometry_RectangleCopyWithImpl()
- ._$ShapeGeometryCopyWithImpl()
- _$ShapeGeometry_SvgCopyWithImpl()
- _$ShapeGeometry_TextCopyWithImpl()
- ShapeGeometryPatterns
- value()

### Community 46 — ../services/commit/commitServiceImpl (18 nodes, cohesion: 0.11)

- branch-switch.test
- @bufbuild/protobuf/create
- bun:test/afterAll
- bun:test/beforeAll
- bun:test/describe
- bun:test/expect
- bun:test/it
- @connectrpc/connect/HandlerContext
- ../db/db
- ../db/schema
- drizzle-orm/eq
- ../gen/vio/v1/branch_pb.js/CreateBranchRequestSchema
- ../gen/vio/v1/canvas_pb.js/GetCanvasStateRequestSchema
- ../gen/vio/v1/canvas_pb.js/RestoreFromSnapshotRequestSchema
- ../gen/vio/v1/commit_pb.js/CreateCommitRequestSchema
- ../services/branch/branchServiceImpl
- ../services/canvas/canvasServiceImpl
- ../services/commit/commitServiceImpl

### Community 47 — seedStressProject() (18 nodes, cohesion: 0.17)

- seed
- cleanupProject()
- createStressConfig()
- extToMime()
- drizzle-orm/eq
- ./index/db
- ./index/schema
- node:crypto/randomUUID
- node:fs/promises/readdir
- node:fs/promises/readFile
- node:path/path
- sharp/sharp
- insertInBatches()
- loadImageSources()
- parseStressLevelArg()
- seed()
- seedDemoProject()
- seedStressProject()

### Community 48 — _CanvasInteractionMixin (18 nodes, cohesion: 0.11)

- canvas_bloc_interaction
- _CanvasInteractionMixin
- ._beginSnapSession()
- ._detectSnap()
- ._endSnapSession()
- ._expandAncestorsForShapes()
- ._expandAncestorsForShapesIn()
- .findShapesAtPoint()
- .findShapesInRect()
- .findTopShapeAtPoint()
- ._nextSortOrderForNewShape()
- ._notifyRepositoryShapeAdded()
- ._notifyRepositoryShapeDeleted()
- ._notifyRepositoryShapeUpdated()
- ._pruneEmptyGroups()
- ._pushUndoState()
- ._shouldRecomputeHover()
- canvas_bloc.dart

### Community 49 — createRouter() (17 nodes, cohesion: 0.12)

- router
- createRouter()
- dart:async
- ../features/assets/bloc/asset_bloc.dart
- ../features/auth/bloc/auth_bloc.dart
- ../features/auth/presentation/login_page.dart
- ../features/auth/presentation/register_page.dart
- ../features/canvas/bloc/canvas_bloc.dart
- ../features/settings/presentation/settings_page.dart
- ../features/version_control/bloc/version_control_bloc.dart
- ../features/workspace/bloc/search_bloc.dart
- ../features/workspace/bloc/workspace_bloc.dart
- ../features/workspace/presentation/workspace_page.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:go_router/go_router.dart
- service_locator.dart

### Community 50 — _single() (17 nodes, cohesion: 0.13)

- canvas_perf_summary
- _asDouble()
- _asInt()
- _decodeMap()
- _distribution()
- double()
- dart:convert
- dart:io
- main()
- _pair()
- _parseArgs()
- _parseLogLine()
- _percentile()
- _PerfSchema
- _printHelp()
- _round()
- _single()

### Community 51 — viewportNotifier() (17 nodes, cohesion: 0.12)

- rust_canvas_painter
- Color()
- ../../../../core/services/image_cache_service.dart
- dart:typed_data
- dart:ui'
- device_frame_painter.dart
- ../../models/selection_handle_metrics.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart'
- ../../../../rust/lib.dart
- ../../../../rust/render/commands.dart
- shape_painter.dart
- ../viewport_notifier.dart
- interactionNotifier()
- Object()
- Rect()
- viewportNotifier()

### Community 52 — _syncStatusController() (16 nodes, cohesion: 0.13)

- grpc_canvas_repository
- _currentStatus()
- dart:async
- ../../gen/vio/v1/canvas.pb.dart'
- ../../gen/vio/v1/canvas.pbgrpc.dart
- ../grpc/grpc_client.dart
- ../grpc/proto_converter.dart
- package:fixnum/fixnum.dart
- package:grpc/grpc.dart
- package:vio_core/vio_core.dart
- _isBranchSwitching()
- _isDirty()
- List()
- _shapesController()
- SyncStatus
- _syncStatusController()

### Community 53 — rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine() (16 nodes, cohesion: 0.13)

- frb_generated
- frbgen_vio_client_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- frbgen_vio_client_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- crate::api::engine::*
- flutter_rust_bridge::for_generated::byteorder::{NativeEndian, ReadBytesExt, WriteBytesExt}
- flutter_rust_bridge::for_generated::{transform_result_dco, Lifetimeable, Lockable}
- flutter_rust_bridge::for_generated::wasm_bindgen
- flutter_rust_bridge::for_generated::wasm_bindgen::prelude::*
- flutter_rust_bridge::{Handler, IntoIntoDart}
- pub use io::*
- pub use web::*
- super::*
- rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine()
- .sse_decode()
- .sse_encode()

### Community 54 — ./common_pb.js/Transform (16 nodes, cohesion: 0.13)

- shape_pb
- @bufbuild/protobuf/codegenv2/enumDesc
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenEnum
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./common_pb.js/EmptySchema
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/Fill
- ./common_pb.js/Stroke
- ./common_pb.js/Timestamp
- ./common_pb.js/Transform

### Community 55 — src/widgets/vio_toolbar.dart (16 nodes, cohesion: 0.13)

- vio_ui_kit
- src/bloc/theme_bloc.dart
- src/icons/vio_icons.dart
- src/theme/vio_canvas_theme.dart
- src/theme/vio_colors.dart
- src/theme/vio_spacing.dart
- src/theme/vio_theme.dart
- src/theme/vio_typography.dart
- src/widgets/vio_button.dart
- src/widgets/vio_color_picker_dialog.dart
- src/widgets/vio_icon_button.dart
- src/widgets/vio_panel.dart
- src/widgets/vio_property_widgets.dart
- src/widgets/vio_search_bar.dart
- src/widgets/vio_text_field.dart
- src/widgets/vio_toolbar.dart

### Community 56 — _effectiveConfig() (16 nodes, cohesion: 0.13)

- grpc_client
- _effectiveConfig()
- ../auth/token_storage.dart
- ../config/app_config.dart
- ../../gen/vio/v1/asset.pbgrpc.dart
- ../../gen/vio/v1/auth.pbgrpc.dart
- ../../gen/vio/v1/branch.pbgrpc.dart
- ../../gen/vio/v1/canvas.pbgrpc.dart
- ../../gen/vio/v1/commit.pbgrpc.dart
- ../../gen/vio/v1/project.pbgrpc.dart
- ../../gen/vio/v1/pullrequest.pbgrpc.dart
- ../../gen/vio/v1/shape.pbgrpc.dart
- grpc_channel.dart
- package:flutter/foundation.dart
- package:grpc/grpc_connection_interface.dart
- package:grpc/service_api.dart'

### Community 57 — ./common_pb.js/Timestamp (57) (16 nodes, cohesion: 0.13)

- branch_pb
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./commit_pb.js/Commit
- ./commit_pb.js/DiffResult
- ./commit_pb.js/file_vio_v1_commit
- ./common_pb.js/EmptySchema
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/MergeStrategy
- ./common_pb.js/ShapeConflict
- ./common_pb.js/Timestamp

### Community 58 — uploadAsset() (16 nodes, cohesion: 0.13)

- asset.pbgrpc
- createColor()
- deleteAsset()
- deleteColor()
- getAsset()
- asset.pb.dart'
- common.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- listAssets()
- listColors()
- updateAsset()
- updateColor()
- uploadAsset()

### Community 59 — TileResult (15 nodes, cohesion: 0.13)

- engine
- ellipse()
- crate::math::aabb::Aabb
- crate::math::matrix2d::Matrix2D
- crate::rasterizer::painter
- crate::rasterizer::tiles::{TileGrid, TileKey}
- crate::render::commands::DrawCommand
- crate::render::generate
- crate::scene_graph::shape::*
- crate::scene_graph::shape::RenderShape
- crate::scene_graph::spatial_index::SpatialIndex
- crate::scene_graph::tree::SceneTree
- std::collections::HashSet
- super::*
- TileResult

### Community 60 — _span() (15 nodes, cohesion: 0.13)

- options
- builder.dart
- dart:io
- environment.dart
- package:collection/collection.dart
- package:ed25519_edwards/ed25519_edwards.dart
- package:hex/hex.dart
- package:logging/logging.dart
- package:path/path.dart'
- package:source_span/source_span.dart
- package:yaml/yaml.dart
- rustup.dart
- _message()
- _span()
- Toolchain

### Community 61 — visible_when_overlapping() (15 nodes, cohesion: 0.26)

- culling
- fully_visible_when_inside()
- crate::math::aabb::Aabb
- crate::math::matrix2d::Matrix2D
- crate::scene_graph::shape::*
- crate::scene_graph::shape::RenderShape
- super::*
- is_shape_fully_visible()
- is_shape_visible()
- make_shape_at()
- not_visible_when_hidden()
- not_visible_when_outside()
- partially_visible_is_visible()
- rotated_shape_uses_aabb()
- visible_when_overlapping()

### Community 62 — updatePullRequest() (15 nodes, cohesion: 0.13)

- pullrequest.pbgrpc
- checkMergeStatus()
- closePullRequest()
- createPullRequest()
- getPullRequest()
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- pullrequest.pb.dart'
- listPullRequests()
- mergePullRequest()
- reopenPullRequest()
- resolveConflicts()
- updatePullRequest()

### Community 63 — getArtifactNames() (15 nodes, cohesion: 0.13)

- artifacts_provider
- AritifactType
- artifactTypeForTarget()
- getArtifactNames()
- builder.dart
- crate_hash.dart
- dart:io
- options.dart
- package:ed25519_edwards/ed25519_edwards.dart
- package:http/http.dart
- package:logging/logging.dart
- package:path/path.dart'
- precompile_binaries.dart
- rustup.dart
- target.dart

### Community 64 — TextAlign (15 nodes, cohesion: 0.13)

- shape
- BlurType
- BoolOp
- GradientType
- ../frb_generated.dart
- ../math/matrix2d.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart
- package:freezed_annotation/freezed_annotation.dart'
- shape.freezed.dart
- ShadowStyle
- ShapeType
- StrokeAlignment
- StrokeCap
- StrokeJoin
- TextAlign

### Community 65 — dataType() (15 nodes, cohesion: 0.13)

- index
- dataType()
- drizzle-orm/pg-core/boolean
- drizzle-orm/pg-core/customType
- drizzle-orm/pg-core/doublePrecision
- drizzle-orm/pg-core/index
- drizzle-orm/pg-core/integer
- drizzle-orm/pg-core/jsonb
- drizzle-orm/pg-core/pgTable
- drizzle-orm/pg-core/real
- drizzle-orm/pg-core/text
- drizzle-orm/pg-core/timestamp
- drizzle-orm/pg-core/uuid
- drizzle-orm/pg-core/varchar
- drizzle-orm/relations

### Community 66 — _ShapeNameSectionState() (14 nodes, cohesion: 0.14)

- right_panel
- _buildHeader()
- ../../bloc/workspace_bloc.dart
- ../../../canvas/bloc/canvas_bloc.dart
- ../../../canvas/models/frame_presets.dart
- frame_preset_picker.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- property_sections.dart
- shape_properties.dart
- _RightPanelState()
- _ShapeNameSectionState()

### Community 67 — ./common_pb.js/Timestamp (67) (14 nodes, cohesion: 0.14)

- project_pb
- ./branch_pb.js/Branch
- ./branch_pb.js/file_vio_v1_branch
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./common_pb.js/EmptySchema
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/PageToken
- ./common_pb.js/Timestamp

### Community 68 — updateBranch() (68) (14 nodes, cohesion: 0.14)

- branch.pbgrpc
- compareBranches()
- createBranch()
- deleteBranch()
- getBranch()
- branch.pb.dart'
- common.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- listBranches()
- mergeBranches()
- updateBranch()

### Community 69 — _WorkspacePageState() (14 nodes, cohesion: 0.14)

- workspace_page
- ../bloc/workspace_bloc.dart
- ../../canvas/bloc/canvas_bloc.dart
- ../../canvas/presentation/canvas_view.dart
- ../../../core/platform_shortcuts.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:flutter/services.dart
- package:go_router/go_router.dart
- package:vio_ui_kit/vio_ui_kit.dart
- widgets/left_panel.dart
- widgets/resizable_panel_handle.dart
- widgets/right_panel.dart
- _WorkspacePageState()

### Community 70 — package:vio_core/vio_core.dart (70) (14 nodes, cohesion: 0.14)

- asset_bloc
- asset_event.dart
- asset_state.dart
- ../../canvas/bloc/canvas_bloc.dart
- ../../../core/grpc/proto_converter.dart
- ../../../core/services/image_cache_service.dart
- dart:typed_data
- ../../../gen/vio/v1/asset.pb.dart'
- ../../../gen/vio/v1/asset.pbgrpc.dart'
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:grpc/grpc.dart
- package:uuid/uuid.dart
- package:vio_core/vio_core.dart

### Community 71 — main() (71) (14 nodes, cohesion: 0.14)

- search_tab_test
- dart:ui
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/features/assets/bloc/asset_bloc.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/features/version_control/bloc/version_control_bloc.dart
- package:vio_client/src/features/workspace/bloc/search_bloc.dart
- package:vio_client/src/features/workspace/presentation/widgets/search_tab.dart
- package:vio_client/src/gen/vio/v1/asset.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()

### Community 72 — services/rust_engine_service.dart (72) (14 nodes, cohesion: 0.14)

- service_locator
- config/app_config.dart
- ../gen/vio/v1/asset.pbgrpc.dart
- ../gen/vio/v1/auth.pbgrpc.dart
- ../gen/vio/v1/branch.pbgrpc.dart
- ../gen/vio/v1/canvas.pbgrpc.dart
- ../gen/vio/v1/commit.pbgrpc.dart
- ../gen/vio/v1/project.pbgrpc.dart
- ../gen/vio/v1/pullrequest.pbgrpc.dart
- ../gen/vio/v1/shape.pbgrpc.dart
- grpc/grpc.dart
- repositories/repositories.dart
- services/preferences_service.dart
- services/rust_engine_service.dart

### Community 73 — _MergePullRequestDialogState() (13 nodes, cohesion: 0.15)

- pull_request_list
- _CreatePullRequestDialogState()
- ../../bloc/version_control_bloc.dart
- conflict_resolution_dialog.dart
- ../../../../gen/vio/v1/branch.pb.dart'
- ../../../../gen/vio/v1/common.pbenum.dart'
- ../../../../gen/vio/v1/pullrequest.pb.dart'
- ../../../../gen/vio/v1/pullrequest.pbenum.dart'
- ../../models/models.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _MergePullRequestDialogState()

### Community 74 — environment() (13 nodes, cohesion: 0.15)

- builder
- BuildConfiguration
- environment()
- android_environment.dart
- cargo.dart
- environment.dart
- options.dart
- package:collection/collection.dart
- package:logging/logging.dart
- package:path/path.dart'
- rustup.dart
- target.dart
- util.dart

### Community 75 — updateShape() (13 nodes, cohesion: 0.15)

- shape.pbgrpc
- batchMutate()
- createShape()
- deleteShape()
- getShape()
- common.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- shape.pb.dart'
- listShapes()
- updateShape()

### Community 76 — ../../version_control/bloc/version_control_bloc.dart (13 nodes, cohesion: 0.15)

- search_bloc
- ../../assets/bloc/asset_bloc.dart
- ../../canvas/bloc/canvas_bloc.dart
- dart:async
- ../../../gen/vio/v1/branch.pb.dart'
- ../../../gen/vio/v1/commit.pb.dart'
- ../../../gen/vio/v1/pullrequest.pb.dart'
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:vio_core/vio_core.dart
- search_event.dart
- search_state.dart
- ../../version_control/bloc/version_control_bloc.dart

### Community 77 — sync_add_update_remove() (13 nodes, cohesion: 0.36)

- .create()
- .hit_test_point()
- .shape_count()
- create_engine()
- hit_test_ellipse_precise()
- hit_test_point_miss()
- hit_test_point_rect()
- hit_test_rect_selection()
- load_all_shapes()
- paint_order()
- query_visible_shapes()
- rect()
- sync_add_update_remove()

### Community 78 — target.dart (78) (13 nodes, cohesion: 0.15)

- precompile_binaries
- artifacts_provider.dart
- builder.dart
- cargo.dart
- crate_hash.dart
- dart:io
- options.dart
- package:ed25519_edwards/ed25519_edwards.dart
- package:github/github.dart
- package:logging/logging.dart
- package:path/path.dart'
- rustup.dart
- target.dart

### Community 79 — revertCommit() (13 nodes, cohesion: 0.15)

- commit.pbgrpc
- checkoutCommit()
- cherryPick()
- createCommit()
- getCommit()
- getDiff()
- commit.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- listCommits()
- revertCommit()

### Community 80 — _GraphicsSectionState() (12 nodes, cohesion: 0.17)

- assets_tab
- _AddColorDialogState()
- _GraphicsSectionState()
- ../../bloc/asset_bloc.dart
- ../../../canvas/bloc/canvas_bloc.dart
- dart:typed_data
- package:desktop_drop/desktop_drop.dart
- package:file_picker/file_picker.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 81 — services/rust_engine_service.dart (12 nodes, cohesion: 0.17)

- core
- auth/token_storage.dart
- config/app_config.dart
- grpc/grpc.dart
- platform_shortcuts.dart
- repositories/repositories.dart
- router.dart
- rust/render_shape_converter.dart
- service_locator.dart
- services/image_cache_service.dart
- services/preferences_service.dart
- services/rust_engine_service.dart

### Community 82 — ./common_pb.js/Timestamp (12 nodes, cohesion: 0.17)

- asset_pb
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./common_pb.js/EmptySchema
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/Gradient
- ./common_pb.js/Timestamp

### Community 83 — CanvasEngine (12 nodes, cohesion: 0.18)

- CanvasEngine
- .generate_draw_commands()
- .hit_test_rect()
- .load_all_shapes()
- .mark_all_tiles_dirty()
- .paint_order()
- .point_in_shape()
- .query_visible()
- .rasterize_dirty_tiles()
- .sync_shapes()
- .tile_cache_stats()
- .tile_rasterized_count()

### Community 84 — timestamp() (12 nodes, cohesion: 0.26)

- logger
- baseReplacer()
- codeName()
- formatBody()
- @connectrpc/connect/Code
- @connectrpc/connect/ConnectError
- @connectrpc/connect/Interceptor
- loggingInterceptor()
- parseRpcPath()
- sanitizeHeaders()
- smartReplacer()
- timestamp()

### Community 85 — unavailable() (12 nodes, cohesion: 0.17)

- errors
- aborted()
- alreadyExists()
- failedPrecondition()
- @connectrpc/connect/Code
- @connectrpc/connect/ConnectError
- internal()
- invalidArgument()
- notFound()
- permissionDenied()
- unauthenticated()
- unavailable()

### Community 86 — updateProject() (12 nodes, cohesion: 0.17)

- project.pbgrpc
- createProject()
- deleteProject()
- getProject()
- common.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- project.pb.dart'
- listProjects()
- updateProject()

### Community 87 — ./shape_pb.js/Shape (12 nodes, cohesion: 0.17)

- canvas_pb
- @bufbuild/protobuf/codegenv2/enumDesc
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenEnum
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./shape_pb.js/file_vio_v1_shape
- ./shape_pb.js/Shape

### Community 88 — syncChanges() (88) (12 nodes, cohesion: 0.17)

- canvas.pbgrpc
- clearWorkingCopy()
- collaborate()
- getCanvasState()
- canvas.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- restoreFromSnapshot()
- streamUpdates()
- syncChanges()

### Community 89 — validateToken() (12 nodes, cohesion: 0.17)

- auth.pbgrpc
- auth.pb.dart'
- common.pb.dart'
- dart:async'
- dart:core'
- package:grpc/service_api.dart'
- package:protobuf/protobuf.dart'
- login()
- logout()
- refreshToken()
- register()
- validateToken()

### Community 90 — widget() (12 nodes, cohesion: 0.17)

- property_sections
- _FillItemState()
- ../../../canvas/bloc/canvas_bloc.dart
- dart:async
- dart:math'
- gradient_editor.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:google_fonts/google_fonts.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- widget()

### Community 91 — _isSupportedDeviceFrameSize() (12 nodes, cohesion: 0.17)

- canvas_bloc_commands
- _CanvasCommandsMixin
- ._effectiveContainerIdFor()
- ._expandAncestorsForShapes()
- ._nextSortOrderForNewShape()
- ._notifyRepositoryShapeAdded()
- ._notifyRepositoryShapeDeleted()
- ._notifyRepositoryShapeUpdated()
- ._pruneEmptyGroups()
- ._pushUndoState()
- canvas_bloc.dart
- _isSupportedDeviceFrameSize()

### Community 92 — ./common_pb.js/Timestamp (92) (11 nodes, cohesion: 0.18)

- commit_pb
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/PageToken
- ./common_pb.js/Timestamp

### Community 93 — package:grpc/grpc.dart (11 nodes, cohesion: 0.18)

- auth_bloc
- auth_event.dart
- auth_state.dart
- ../../../core/auth/token_storage.dart
- ../../../core/grpc/grpc_client.dart
- dart:async
- ../../../gen/vio/v1/auth.pbgrpc.dart
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/foundation.dart
- package:grpc/grpc.dart

### Community 94 — wire__crate__api__simple__greet_impl() (11 nodes, cohesion: 0.18)

- pde_ffi_dispatcher_sync_impl()
- wire__crate__api__engine__CanvasEngine_create_impl()
- wire__crate__api__engine__CanvasEngine_generate_draw_commands_impl()
- wire__crate__api__engine__CanvasEngine_hit_test_point_impl()
- wire__crate__api__engine__CanvasEngine_hit_test_rect_impl()
- wire__crate__api__engine__CanvasEngine_paint_order_impl()
- wire__crate__api__engine__CanvasEngine_query_visible_impl()
- wire__crate__api__engine__CanvasEngine_shape_count_impl()
- wire__crate__api__engine__CanvasEngine_tile_cache_stats_impl()
- wire__crate__api__engine__CanvasEngine_tile_rasterized_count_impl()
- wire__crate__api__simple__greet_impl()

### Community 95 — _LeftPanelState() (11 nodes, cohesion: 0.18)

- left_panel
- ../../../assets/presentation/widgets/assets_tab.dart
- ../../../canvas/presentation/widgets/layer_tree.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/features/version_control/presentation/widgets/version_control_tab.dart
- package:vio_client/src/features/workspace/bloc/workspace_bloc.dart
- package:vio_ui_kit/vio_ui_kit.dart
- search_tab.dart
- _LeftPanelState()

### Community 96 — widget() (96) (11 nodes, cohesion: 0.18)

- shape_properties
- _FramePropertiesState()
- ../../../canvas/bloc/canvas_bloc.dart
- ../../../canvas/models/frame_presets.dart
- dart:math'
- frame_preset_picker.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- widget()

### Community 97 — timestampToDateTime() (11 nodes, cohesion: 0.25)

- BranchExt
- .timestampToDateTime()
- CommitExt
- .createdAt()
- PullRequestExt
- .createdAt()
- .timestampToDateTime()
- .updatedAt()
- TimestampExt
- .DateTime()
- timestampToDateTime()

### Community 98 — ./common_pb.js/Timestamp (98) (11 nodes, cohesion: 0.18)

- auth_pb
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/GenService
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/codegenv2/serviceDesc
- @bufbuild/protobuf/Message
- ./common_pb.js/EmptySchema
- ./common_pb.js/file_vio_v1_common
- ./common_pb.js/Timestamp

### Community 99 — _SearchTabState() (10 nodes, cohesion: 0.20)

- search_tab
- Center()
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_client/src/features/version_control/bloc/version_control_bloc.dart
- package:vio_client/src/features/workspace/bloc/search_bloc.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- Padding()
- _SearchTabState()

### Community 100 — main() (100) (10 nodes, cohesion: 0.20)

- grpc_canvas_repository_sync_behavior_test
- dart:async
- package:fixnum/fixnum.dart
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/core/repositories/grpc_canvas_repository.dart
- package:vio_client/src/gen/vio/v1/canvas.pb.dart'
- package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()

### Community 101 — main() (101) (10 nodes, cohesion: 0.20)

- search_bloc_test
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/features/assets/bloc/asset_bloc.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/features/version_control/bloc/version_control_bloc.dart
- package:vio_client/src/features/workspace/bloc/search_bloc.dart
- package:vio_client/src/gen/vio/v1/asset.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()

### Community 102 — ResolutionChoiceDisplay (10 nodes, cohesion: 0.20)

- proto_extensions
- ../../gen/vio/v1/branch.pb.dart'
- ../../gen/vio/v1/commit.pb.dart'
- ../../gen/vio/v1/common.pb.dart'
- ../../gen/vio/v1/common.pbenum.dart'
- ../../gen/vio/v1/pullrequest.pb.dart'
- ../../gen/vio/v1/pullrequest.pbenum.dart'
- MergeStrategyDisplay
- PullRequestStatusDisplay
- ResolutionChoiceDisplay

### Community 103 — _RustCanvasLayerState() (10 nodes, cohesion: 0.20)

- rust_canvas_layer
- ../../bloc/canvas_bloc.dart
- ../../../../core/services/rust_engine_service.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- ../painters/rust_canvas_painter.dart
- ../../../../rust/render/commands.dart
- ../viewport_notifier.dart
- _RustCanvasLayerState()

### Community 104 — version_control_tab.dart (10 nodes, cohesion: 0.20)

- widgets
- branch_list_panel.dart
- branch_selector_header.dart
- branch_settings_dialog.dart
- commit_dialog.dart
- commit_history_list.dart
- commit_panel.dart
- conflict_resolution_dialog.dart
- pull_request_list.dart
- version_control_tab.dart

### Community 105 — _CommitPanelState() (10 nodes, cohesion: 0.20)

- commit_panel
- _ChangeItemState()
- _CommitPanelState()
- ../../bloc/version_control_bloc.dart
- ../../../canvas/bloc/canvas_bloc.dart
- ../../../../core/core.dart
- ../../models/models.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 106 — Rect() (106) (10 nodes, cohesion: 0.20)

- frame_shape
- FlexAlign
- FlexDirection
- FlexJustify
- FrameFlexLayout()
- FrameGridLayout()
- FrameShape()
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()

### Community 107 — _TileCompositorLayerState() (10 nodes, cohesion: 0.20)

- tile_compositor_layer
- ../../bloc/canvas_bloc.dart
- ../../../../core/services/rust_engine_service.dart
- dart:async
- dart:typed_data
- dart:ui'
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- ../../../../rust/api/engine.dart
- _TileCompositorLayerState()

### Community 108 — _LayerItemState() (10 nodes, cohesion: 0.20)

- layer_item
- ../../bloc/canvas_bloc.dart
- ../../../../core/platform_shortcuts.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:flutter/services.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _LayerContextAction
- _LayerItemState()

### Community 109 — Utf8FromUtf16() (10 nodes, cohesion: 0.36)

- utils
- CreateAndAttachConsole()
- GetCommandLineArguments()
- flutter_windows.h
- io.h
- iostream
- stdio.h
- utils.h
- windows.h
- Utf8FromUtf16()

### Community 110 — SyncOperationType (10 nodes, cohesion: 0.20)

- proto_converter
- dart:convert
- dart:typed_data
- dart:ui'
- ../../gen/vio/v1/asset.pb.dart'
- ../../gen/vio/v1/canvas.pb.dart'
- ../../gen/vio/v1/common.pb.dart'
- ../../gen/vio/v1/shape.pb.dart'
- package:vio_core/vio_core.dart
- SyncOperationType

### Community 111 — _enabled() (10 nodes, cohesion: 0.20)

- canvas_performance_diagnostics
- double()
- _enabled()
- dart:async
- dart:convert
- package:flutter/foundation.dart
- package:flutter/scheduler.dart
- package:flutter/widgets.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_core/vio_core.dart

### Community 112 — world_aabb_with_translation() (10 nodes, cohesion: 0.33)

- is_container_for_frame()
- is_not_container_for_rectangle()
- local_bounds_of_rectangle()
- make_rect_shape()
- RenderShape
- .clips_content()
- .is_container()
- .local_bounds()
- .world_aabb()
- world_aabb_with_translation()

### Community 113 — main() (113) (10 nodes, cohesion: 0.20)

- main
- package:flutter/foundation.dart
- package:flutter/material.dart
- package:hydrated_bloc/hydrated_bloc.dart
- package:path_provider/path_provider.dart
- package:vio_core/vio_core.dart
- src/app.dart
- src/core/core.dart
- src/rust/frb_generated.dart
- main()

### Community 114 — target.dart (114) (10 nodes, cohesion: 0.20)

- verify_binaries
- artifacts_provider.dart
- cargo.dart
- crate_hash.dart
- dart:io
- options.dart
- package:ed25519_edwards/ed25519_edwards.dart
- package:http/http.dart
- precompile_binaries.dart
- target.dart

### Community 115 — _CreatePRFromBranchDialogState() (10 nodes, cohesion: 0.20)

- branch_list_panel
- _BranchListItemState()
- _BranchListPanelState()
- _CreatePRFromBranchDialogState()
- ../../bloc/version_control_bloc.dart
- branch_settings_dialog.dart
- ../../../../gen/vio/v1/branch.pb.dart'
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 116 — make_shapes() (10 nodes, cohesion: 0.27)

- scene_bench
- bench_hit_test()
- bench_spatial_index_build()
- bench_visibility_query()
- criterion::{criterion_group, criterion_main, BenchmarkId, Criterion}
- rust_lib_vio_client::api::engine::CanvasEngine
- rust_lib_vio_client::math::matrix2d::Matrix2D
- rust_lib_vio_client::scene_graph::shape::*
- rust_lib_vio_client::scene_graph::spatial_index::SpatialIndex
- make_shapes()

### Community 117 — widget() (117) (9 nodes, cohesion: 0.22)

- conflict_resolution_dialog
- _ConflictResolutionDialogState()
- ../../../../gen/vio/v1/common.pb.dart'
- ../../../../gen/vio/v1/common.pbenum.dart'
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _resolutions()
- widget()

### Community 118 — showBranchSettingsDialog() (9 nodes, cohesion: 0.22)

- branch_settings_dialog
- _BranchSettingsDialogState()
- ../../bloc/version_control_bloc.dart
- ../../../../core/core.dart
- ../../../../gen/vio/v1/branch.pb.dart'
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart
- showBranchSettingsDialog()

### Community 119 — center() (9 nodes, cohesion: 0.25)

- Aabb
- .center_x()
- .center_y()
- .contains()
- .contains_point()
- .inflate()
- .new()
- .union()
- center()

### Community 120 — TextButton() (9 nodes, cohesion: 0.22)

- vio_button
- ElevatedButton()
- package:flutter/material.dart
- ../theme/vio_spacing.dart
- ../theme/vio_typography.dart
- OutlinedButton()
- TextButton()
- VioButtonSize
- VioButtonVariant

### Community 121 — _pending() (9 nodes, cohesion: 0.22)

- image_cache_service
- _cache()
- _imageDecodedController()
- dart:async
- dart:math'
- dart:typed_data
- dart:ui'
- package:image/image.dart'
- _pending()

### Community 122 — writePerfLog() (9 nodes, cohesion: 0.31)

- perf-diagnostics
- ensureLogFileReady()
- getPerfDiagnosticsConfig()
- node:fs/promises/appendFile
- node:fs/promises/mkdir
- node:path/path
- serializeError()
- startPerfSpan()
- writePerfLog()

### Community 123 — _yPoints() (9 nodes, cohesion: 0.22)

- snap
- dart:math'
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Offset()
- SnapAxis
- SnapPointType
- _xPoints()
- _yPoints()

### Community 124 — runCommand() (9 nodes, cohesion: 0.22)

- util
- dart:convert
- dart:io
- logging.dart
- package:logging/logging.dart
- package:path/path.dart'
- rustup.dart
- _resolveExecutable()
- runCommand()

### Community 125 — target.dart (9 nodes, cohesion: 0.22)

- build_gradle
- artifacts_provider.dart
- builder.dart
- dart:io
- environment.dart
- options.dart
- package:logging/logging.dart
- package:path/path.dart'
- target.dart

### Community 126 — util.dart (9 nodes, cohesion: 0.22)

- android_environment
- dart:io
- dart:isolate
- dart:math'
- package:collection/collection.dart
- package:path/path.dart'
- package:version/version.dart
- target.dart
- util.dart

### Community 127 — RegisterGeneratedPlugins (127) (9 nodes, cohesion: 0.22)

- GeneratedPluginRegistrant
- desktop_drop
- file_picker
- flutter_secure_storage_darwin
- FlutterMacOS
- Foundation
- path_provider_foundation
- shared_preferences_foundation
- RegisterGeneratedPlugins

### Community 128 — main() (128) (9 nodes, cohesion: 0.22)

- canvas_selection_rotation_test
- dart:math'
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/core/repositories/grpc_canvas_repository.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()

### Community 129 — _computeHandles() (9 nodes, cohesion: 0.22)

- selection_box_painter
- _computeCornerRadiusHandles()
- _computeHandles()
- dart:math'
- ../../models/handle_types.dart
- ../../models/selection_handle_metrics.dart
- package:flutter/foundation.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart

### Community 130 — _wrap() (9 nodes, cohesion: 0.22)

- settings_page_test
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:vio_client/src/features/settings/presentation/settings_page.dart
- package:vio_client/src/features/settings/presentation/widgets/theme_section.dart
- package:vio_ui_kit/vio_ui_kit.dart
- main()
- _wrap()

### Community 131 — to_gradient_data() (9 nodes, cohesion: 0.42)

- apply_alpha_to_color()
- apply_alpha_to_color_works()
- combined_alpha()
- emit_fill()
- emit_fill_for_oval()
- emit_fill_for_rrect()
- emit_text_commands()
- first_visible_fill_color()
- to_gradient_data()

### Community 132 — _textPainterCache() (9 nodes, cohesion: 0.22)

- shape_painter
- ../../../../core/services/image_cache_service.dart
- dart:typed_data
- dart:ui'
- package:flutter/material.dart
- package:google_fonts/google_fonts.dart
- package:vio_core/vio_core.dart
- Object()
- _textPainterCache()

### Community 133 — util.dart (133) (9 nodes, cohesion: 0.22)

- build_pod
- artifacts_provider.dart
- builder.dart
- dart:io
- environment.dart
- options.dart
- package:path/path.dart'
- target.dart
- util.dart

### Community 134 — _settleBloc() (9 nodes, cohesion: 0.22)

- canvas_frame_select_by_click_test
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/core/repositories/grpc_canvas_repository.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()
- _settleBloc()

### Community 135 — shape_painter.dart (8 nodes, cohesion: 0.25)

- canvas_painter
- ../../bloc/canvas_bloc.dart
- device_frame_painter.dart
- ../../models/selection_handle_metrics.dart
- package:flutter/foundation.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- shape_painter.dart

### Community 136 — @bufbuild/protobuf/Message (8 nodes, cohesion: 0.25)

- common_pb
- @bufbuild/protobuf/codegenv2/enumDesc
- @bufbuild/protobuf/codegenv2/fileDesc
- @bufbuild/protobuf/codegenv2/GenEnum
- @bufbuild/protobuf/codegenv2/GenFile
- @bufbuild/protobuf/codegenv2/GenMessage
- @bufbuild/protobuf/codegenv2/messageDesc
- @bufbuild/protobuf/Message

### Community 137 — titleSmall() (8 nodes, cohesion: 0.25)

- vio_typography
- bodyMedium()
- package:flutter/material.dart
- package:google_fonts/google_fonts.dart
- vio_colors.dart
- _inter()
- _mono()
- titleSmall()

### Community 138 — ../theme/vio_theme.dart (8 nodes, cohesion: 0.25)

- theme_bloc
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- theme_event.dart
- theme_state.dart
- ../theme/vio_colors.dart
- ../theme/vio_theme.dart

### Community 139 — main() (139) (8 nodes, cohesion: 0.25)

- canvas_duplicate_persistence_test
- package:flutter_test/flutter_test.dart
- package:grpc/grpc.dart
- package:vio_client/src/core/repositories/grpc_canvas_repository.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_client/src/gen/vio/v1/canvas.pbgrpc.dart
- package:vio_core/vio_core.dart
- main()

### Community 140 — _CreateBranchDialogState() (8 nodes, cohesion: 0.25)

- branch_selector_header
- _CreateBranchDialogState()
- ../../bloc/version_control_bloc.dart
- commit_dialog.dart
- ../../../../gen/vio/v1/branch.pb.dart'
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 141 — _CanvasTextMixin (8 nodes, cohesion: 0.25)

- canvas_bloc_text
- _CanvasTextMixin
- ._expandAncestorsForShapes()
- ._notifyRepositoryShapeAdded()
- ._notifyRepositoryShapeDeleted()
- ._notifyRepositoryShapeUpdated()
- ._pushUndoState()
- canvas_bloc.dart

### Community 142 — SelectionEdgeX (8 nodes, cohesion: 0.25)

- selection_hit_test
- hitTestSelectionAffordance()
- dart:math'
- handle_types.dart
- package:flutter/material.dart
- selection_handle_metrics.dart
- SelectionEdge
- SelectionEdgeX

### Community 143 — target.dart (143) (8 nodes, cohesion: 0.25)

- build_cmake
- artifacts_provider.dart
- builder.dart
- dart:io
- environment.dart
- options.dart
- package:path/path.dart'
- target.dart

### Community 144 — _CanvasHierarchyMixin (8 nodes, cohesion: 0.25)

- canvas_bloc_hierarchy
- _CanvasHierarchyMixin
- ._getTransformedBounds()
- ._notifyRepositoryShapeAdded()
- ._notifyRepositoryShapeDeleted()
- ._notifyRepositoryShapeUpdated()
- ._pushUndoState()
- canvas_bloc.dart

### Community 145 — sleep() (8 nodes, cohesion: 0.39)

- dev-preflight
- ensureBackendDependencies()
- ensurePostgresWithPodmanRunFallback()
- node:fs/existsSync
- run()
- runCapture()
- runDbPush()
- sleep()

### Community 146 — OnDestroy() (8 nodes, cohesion: 0.68)

- flutter_window
- FlutterWindow()
- flutter/generated_plugin_registrant.h
- flutter_window.h
- optional
- MessageHandler()
- OnCreate()
- OnDestroy()

### Community 147 — _VersionControlTabState() (8 nodes, cohesion: 0.25)

- version_control_tab
- ../../bloc/version_control_bloc.dart
- ../../../../gen/vio/v1/branch.pb.dart'
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_client/src/features/version_control/presentation/presentation.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _VersionControlTabState()

### Community 148 — package:path/path.dart' (8 nodes, cohesion: 0.25)

- crate_hash
- dart:convert
- dart:io
- dart:typed_data
- package:collection/collection.dart
- package:convert/convert.dart
- package:crypto/crypto.dart
- package:path/path.dart'

### Community 149 — tile_world_size_at_zoom_1() (7 nodes, cohesion: 0.29)

- keys_for_aabb_crossing_tiles()
- keys_for_negative_coords()
- keys_for_small_aabb()
- tile_world_bounds()
- tile_world_size_at_zoom_1()
- .evict_distant_tiles()
- .new()

### Community 150 — Object() (7 nodes, cohesion: 0.29)

- matrix2d
- format()
- dart:math'
- math()
- Matrix2D()
- multiply()
- Object()

### Community 151 — _VioAppState() (7 nodes, cohesion: 0.29)

- app
- core/core.dart
- features/auth/bloc/auth_bloc.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _VioAppState()

### Community 152 — main() (152) (7 nodes, cohesion: 0.29)

- selection_hit_test_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:vio_client/src/features/canvas/models/handle_types.dart
- package:vio_client/src/features/canvas/models/selection_handle_metrics.dart
- package:vio_client/src/features/canvas/models/selection_hit_test.dart
- main()

### Community 153 — wWinMain() (7 nodes, cohesion: 0.29)

- main
- flutter/dart_project.h
- flutter/flutter_view_controller.h
- flutter_window.h
- utils.h
- windows.h
- wWinMain()

### Community 154 — toProtoUser() (7 nodes, cohesion: 0.57)

- generateAccessToken()
- generateRefreshToken()
- login()
- refreshToken()
- register()
- toProtoTimestamp()
- toProtoUser()

### Community 155 — _RegisterPageState() (7 nodes, cohesion: 0.29)

- register_page
- buildAuthInputDecoration()
- ../bloc/auth_bloc.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:go_router/go_router.dart
- _RegisterPageState()

### Community 156 — _zoom() (7 nodes, cohesion: 0.29)

- viewport_notifier
- package:flutter/widgets.dart
- package:vio_core/vio_core.dart
- _offset()
- _size()
- _viewMatrix()
- _zoom()

### Community 157 — OffsetExtensions (7 nodes, cohesion: 0.29)

- offset_extensions
- _DoubleAngle
- .math()
- dart:math'
- dart:ui
- OffsetExtensions
- .Offset()

### Community 158 — platformSingleActivator() (7 nodes, cohesion: 0.29)

- platform_shortcuts
- package:flutter/foundation.dart
- package:flutter/services.dart
- package:flutter/widgets.dart
- isPlatformModifierPressed()
- platformModifierLabel()
- platformSingleActivator()

### Community 159 — package:vio_ui_kit/vio_ui_kit.dart (159) (7 nodes, cohesion: 0.29)

- commit_history_list
- ../../bloc/version_control_bloc.dart
- ../../../../core/core.dart
- ../../../../gen/vio/v1/commit.pb.dart'
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 160 — main() (160) (7 nodes, cohesion: 0.29)

- render_shape_converter_test
- dart:ui'
- package:flutter_test/flutter_test.dart
- package:vio_client/src/core/rust/render_shape_converter.dart
- package:vio_client/src/rust/scene_graph/shape.dart'
- package:vio_core/vio_core.dart
- main()

### Community 161 — StrokeData (7 nodes, cohesion: 0.29)

- commands
- draw_command_clone()
- DrawCommand
- gradient_data_construction()
- GradientData
- super::*
- StrokeData

### Community 162 — TileKey (7 nodes, cohesion: 0.29)

- tiles
- CachedTile
- dirty_tiles_in_viewport()
- crate::math::aabb::Aabb
- std::collections::{HashMap, HashSet}
- super::*
- TileKey

### Community 163 — _VioColorPickerDialogState() (7 nodes, cohesion: 0.29)

- vio_color_picker_dialog
- package:flutter/material.dart
- package:flutter/services.dart
- ../theme/vio_colors.dart
- ../theme/vio_spacing.dart
- ../theme/vio_typography.dart
- _VioColorPickerDialogState()

### Community 164 — updatePullRequest() (164) (7 nodes, cohesion: 0.29)

- closePullRequest()
- createPullRequest()
- getPullRequest()
- reopenPullRequest()
- resolveConflicts()
- toProtoPullRequest()
- updatePullRequest()

### Community 165 — engine() (7 nodes, cohesion: 0.29)

- rust_engine_service
- engine()
- package:flutter/foundation.dart
- package:vio_core/vio_core.dart
- ../../rust/api/engine.dart
- ../../rust/render/commands.dart
- ../../rust/scene_graph/shape.dart

### Community 166 — _GradientEditorState() (7 nodes, cohesion: 0.29)

- gradient_editor
- FillType
- _GradientEditorState()
- dart:math'
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 167 — wire__crate__api__simple__init_app_impl() (6 nodes, cohesion: 0.33)

- pde_ffi_dispatcher_primary_impl()
- wire__crate__api__engine__CanvasEngine_load_all_shapes_impl()
- wire__crate__api__engine__CanvasEngine_mark_all_tiles_dirty_impl()
- wire__crate__api__engine__CanvasEngine_rasterize_dirty_tiles_impl()
- wire__crate__api__engine__CanvasEngine_sync_shapes_impl()
- wire__crate__api__simple__init_app_impl()

### Community 168 — package:freezed_annotation/freezed_annotation.dart' (6 nodes, cohesion: 0.33)

- commands
- commands.freezed.dart
- ../frb_generated.dart
- ../lib.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart
- package:freezed_annotation/freezed_annotation.dart'

### Community 169 — Rect() (169) (6 nodes, cohesion: 0.33)

- image_shape
- ImageScaleMode
- ImageShape()
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()

### Community 170 — widgets/theme_section.dart (6 nodes, cohesion: 0.33)

- settings_page
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:go_router/go_router.dart
- package:vio_ui_kit/vio_ui_kit.dart
- widgets/theme_section.dart

### Community 171 — main() (171) (6 nodes, cohesion: 0.33)

- theme_bloc_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:google_fonts/google_fonts.dart
- package:vio_ui_kit/vio_ui_kit.dart
- main()

### Community 172 — Rect() (172) (6 nodes, cohesion: 0.33)

- bool_shape
- BoolOperation
- BoolShape()
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()

### Community 173 — _log() (6 nodes, cohesion: 0.73)

- logging
- enableVerboseLogging()
- dart:io
- package:logging/logging.dart
- initLogging()
- _log()

### Community 174 — vio_typography.dart (6 nodes, cohesion: 0.33)

- vio_theme
- package:flutter/material.dart
- vio_canvas_theme.dart
- vio_colors.dart
- vio_spacing.dart
- vio_typography.dart

### Community 175 — _FramePresetPickerState() (6 nodes, cohesion: 0.33)

- frame_preset_picker
- framePresetCategories()
- _FramePresetPickerState()
- ../../../canvas/models/frame_presets.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 176 — authInterceptor() (6 nodes, cohesion: 0.33)

- auth
- authInterceptor()
- @connectrpc/connect/Code
- @connectrpc/connect/ConnectError
- @connectrpc/connect/Interceptor
- ../services/auth.js/validateAccessToken

### Community 177 — selectedShapeIds() (6 nodes, cohesion: 0.33)

- canvas_state
- canvas_bloc.dart
- InteractionMode
- orderedShapes()
- selectedShapeIds()
- SelectionCursorKind

### Community 178 — Rect() (178) (6 nodes, cohesion: 0.33)

- ellipse_shape
- EllipseShape()
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Offset()
- Rect()

### Community 179 — main() (179) (6 nodes, cohesion: 0.33)

- canvas_status_widgets_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:vio_client/src/core/core.dart
- package:vio_client/src/features/canvas/presentation/widgets/canvas_status_widgets.dart
- main()

### Community 180 — extractWebpDimensions() (6 nodes, cohesion: 0.33)

- extractDimensions()
- extractGifDimensions()
- extractJpegDimensions()
- extractPngDimensions()
- extractSvgDimensions()
- extractWebpDimensions()

### Community 181 — _LoginPageState() (6 nodes, cohesion: 0.33)

- login_page
- ../bloc/auth_bloc.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:go_router/go_router.dart
- _LoginPageState()

### Community 182 — NumExtensions (6 nodes, cohesion: 0.33)

- num_extensions
- DoubleExtensions
- dart:math'
- IntExtensions
- NumExtensions
- .closeTo()

### Community 183 — not_rasterizable_with_shadow() (6 nodes, cohesion: 0.33)

- is_tile_rasterizable()
- not_rasterizable_container()
- not_rasterizable_hidden()
- not_rasterizable_inside_clipping_frame_via_frame_id()
- not_rasterizable_text()
- not_rasterizable_with_shadow()

### Community 184 — package:vio_core/vio_core.dart (184) (6 nodes, cohesion: 0.33)

- layer_tree
- ../../bloc/canvas_bloc.dart
- layer_item.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart

### Community 185 — value() (6 nodes, cohesion: 0.33)

- result
- error()
- FutureToResult
- package:flutter/foundation.dart
- NullableToResult
- value()

### Community 186 — main() (186) (6 nodes, cohesion: 0.33)

- simple_test
- package:flutter_test/flutter_test.dart
- package:integration_test/integration_test.dart
- package:vio_client/src/app.dart
- package:vio_client/src/rust/frb_generated.dart
- main()

### Community 187 — RectExtensions (6 nodes, cohesion: 0.33)

- rect_extensions
- dart:math'
- dart:ui
- RectExtensions
- .inflateBy()
- .Offset()

### Community 188 — applicationSupportsSecureRestorableState (6 nodes, cohesion: 0.67)

- AppDelegate
- AppDelegate
- applicationShouldTerminateAfterLastWindowClosed
- applicationSupportsSecureRestorableState
- Cocoa
- FlutterMacOS

### Community 189 — main() (189) (6 nodes, cohesion: 0.33)

- canvas_input_layer_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:vio_client/src/features/canvas/presentation/widgets/canvas_input_layer.dart
- package:vio_core/vio_core.dart
- main()

### Community 190 — ProjectColor() (6 nodes, cohesion: 0.33)

- project_asset
- dart:typed_data
- package:equatable/equatable.dart
- package:vio_core/vio_core.dart
- ProjectAsset()
- ProjectColor()

### Community 191 — sleep() (191) (6 nodes, cohesion: 2.20)

- createRoutes()
- ensureAdminUserWithRetry()
- handler()
- isAllowedOrigin()
- setCorsHeaders()
- sleep()

### Community 192 — _VioSearchBarState() (6 nodes, cohesion: 0.33)

- vio_search_bar
- package:flutter/material.dart
- ../theme/vio_spacing.dart
- ../theme/vio_typography.dart
- vio_icon_button.dart
- _VioSearchBarState()

### Community 193 — _installedToolchains() (6 nodes, cohesion: 0.33)

- rustup
- dart:io
- package:collection/collection.dart
- package:path/path.dart'
- util.dart
- _installedToolchains()

### Community 194 — main() (194) (6 nodes, cohesion: 0.33)

- vio_theme_seed_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:google_fonts/google_fonts.dart
- package:vio_ui_kit/vio_ui_kit.dart
- main()

### Community 195 — Size (6 nodes, cohesion: 0.33)

- win32_window
- functional
- memory
- string
- windows.h
- Size

### Community 196 — FlutterWindow() (6 nodes, cohesion: 0.33)

- flutter_window
- FlutterWindow()
- flutter/dart_project.h
- flutter/flutter_view_controller.h
- memory
- win32_window.h

### Community 197 — testExample (6 nodes, cohesion: 0.67)

- RunnerTests
- Cocoa
- FlutterMacOS
- XCTest
- RunnerTests
- testExample

### Community 198 — workspace_state.dart (5 nodes, cohesion: 0.40)

- workspace_bloc
- package:equatable/equatable.dart
- package:flutter_bloc/flutter_bloc.dart
- workspace_event.dart
- workspace_state.dart

### Community 199 — package:vio_core/vio_core.dart (199) (5 nodes, cohesion: 0.40)

- snap_guides_painter
- dart:typed_data
- dart:ui'
- package:flutter/material.dart
- package:vio_core/vio_core.dart

### Community 200 — toProtoCommit() (5 nodes, cohesion: 0.40)

- checkoutCommit()
- cherryPick()
- createCommit()
- revertCommit()
- toProtoCommit()

### Community 201 — Rect() (5 nodes, cohesion: 0.40)

- path_shape
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- PathShape()
- Rect()

### Community 202 — run() (5 nodes, cohesion: 0.40)

- proto-generate
- commandExists()
- node:child_process/spawnSync
- node:path
- run()

### Community 203 — withDbTimeout() (203) (5 nodes, cohesion: 0.40)

- ensureAdminUser()
- logout()
- validateAccessToken()
- validateToken()
- withDbTimeout()

### Community 204 — ../../rust/scene_graph/shape.dart' (5 nodes, cohesion: 0.40)

- render_shape_converter
- dart:ui'
- package:vio_core/vio_core.dart
- ../../rust/math/matrix2d.dart'
- ../../rust/scene_graph/shape.dart'

### Community 205 — SvgShape() (5 nodes, cohesion: 0.40)

- svg_shape
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()
- SvgShape()

### Community 206 — value() (206) (5 nodes, cohesion: 0.40)

- uuid_value
- package:flutter/foundation.dart
- package:uuid/uuid.dart'
- UuidGenerator
- value()

### Community 207 — _VioColorPickerState() (5 nodes, cohesion: 0.40)

- vio_property_widgets
- package:flutter/material.dart
- package:flutter/services.dart
- package:vio_ui_kit/vio_ui_kit.dart
- _VioColorPickerState()

### Community 208 — rasterize_tile_with_zoom() (5 nodes, cohesion: 0.40)

- is_rasterizable_simple_rect()
- make_rect()
- not_rasterizable_inside_clipping_frame()
- rasterize_tile_red_rect_has_red_pixels()
- rasterize_tile_with_zoom()

### Community 209 — Size() (5 nodes, cohesion: 0.40)

- vio_toolbar
- package:flutter/material.dart
- ../theme/vio_spacing.dart
- vio_icon_button.dart
- Size()

### Community 210 — RectangleShape() (5 nodes, cohesion: 0.40)

- rectangle_shape
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()
- RectangleShape()

### Community 211 — zoom_change_clears_tiles() (5 nodes, cohesion: 0.60)

- new_grid_is_empty()
- .cached_tile_count()
- .occupied_tile_count()
- .zoom()
- zoom_change_clears_tiles()

### Community 212 — package:vio_core/vio_core.dart' (5 nodes, cohesion: 0.40)

- device_frame_painter
- dart:typed_data
- dart:ui'
- package:flutter/material.dart
- package:vio_core/vio_core.dart'

### Community 213 — conflicts() (5 nodes, cohesion: 0.40)

- pull_request_detail
- conflicts()
- ../../../gen/vio/v1/branch.pb.dart'
- ../../../gen/vio/v1/common.pb.dart'
- ../../../gen/vio/v1/pullrequest.pb.dart'

### Community 214 — Rect() (214) (5 nodes, cohesion: 0.40)

- group_shape
- GroupShape()
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()

### Community 215 — main() (215) (5 nodes, cohesion: 0.40)

- vio_search_bar_test
- package:flutter/material.dart
- package:flutter_test/flutter_test.dart
- package:vio_ui_kit/vio_ui_kit.dart
- main()

### Community 216 — _CollapsiblePanelState() (5 nodes, cohesion: 0.40)

- vio_panel
- _CollapsiblePanelState()
- package:flutter/material.dart
- ../theme/vio_spacing.dart
- ../theme/vio_typography.dart

### Community 217 — services/services.dart (5 nodes, cohesion: 0.40)

- grpc
- grpc_client.dart
- proto_converter.dart
- proto_extensions.dart
- services/services.dart

### Community 218 — main() (218) (5 nodes, cohesion: 0.40)

- proto_converter_fill_test
- package:flutter_test/flutter_test.dart
- package:vio_client/src/core/grpc/proto_converter.dart
- package:vio_core/vio_core.dart
- main()

### Community 219 — updateColor() (5 nodes, cohesion: 0.50)

- createColor()
- dbGradientToProto()
- protoGradientToDb()
- toProtoColor()
- updateColor()

### Community 220 — toProtoTimestamp() (220) (5 nodes, cohesion: 0.60)

- getCanvasState()
- stringToShapeType()
- stringToStrokeAlignment()
- toProtoShape()
- toProtoTimestamp()

### Community 221 — RegisterPlugins() (5 nodes, cohesion: 0.40)

- generated_plugin_registrant
- desktop_drop/desktop_drop_plugin.h
- flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h
- generated_plugin_registrant.h
- RegisterPlugins()

### Community 222 — VioIconButtonVariant (5 nodes, cohesion: 0.40)

- vio_icon_button
- package:flutter/material.dart
- ../theme/vio_colors.dart
- ../theme/vio_spacing.dart
- VioIconButtonVariant

### Community 223 — HandlePositionExtension (5 nodes, cohesion: 0.40)

- handle_types
- CornerPosition
- HandlePosition
- HandlePositionExtension
- dart:ui

### Community 224 — package:vio_core/vio_core.dart (224) (5 nodes, cohesion: 0.40)

- canvas_text_editor_overlay
- package:flutter/material.dart
- package:google_fonts/google_fonts.dart
- package:vio_client/src/features/canvas/bloc/canvas_bloc.dart
- package:vio_core/vio_core.dart

### Community 225 — rasterize_with_stroke() (5 nodes, cohesion: 0.40)

- rasterize_rounded_rect()
- rasterize_tile()
- rasterize_tile_outside_bounds_is_transparent()
- rasterize_tile_produces_correct_size()
- rasterize_with_stroke()

### Community 226 — MouseRegion() (5 nodes, cohesion: 0.40)

- canvas_input_layer
- package:flutter/gestures.dart
- package:flutter/material.dart
- package:vio_core/vio_core.dart
- MouseRegion()

### Community 227 — TextShape() (5 nodes, cohesion: 0.40)

- text_shape
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart
- Rect()
- TextShape()

### Community 228 — _inner() (5 nodes, cohesion: 0.40)

- lib
- frb_generated.dart
- package:collection/collection.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart
- _inner()

### Community 229 — MainFlutterWindow (5 nodes, cohesion: 0.80)

- MainFlutterWindow
- awakeFromNib
- Cocoa
- FlutterMacOS
- MainFlutterWindow

### Community 230 — RustLib() (5 nodes, cohesion: 0.50)

- simple
- greet()
- ../frb_generated.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart
- RustLib()

### Community 231 — updateShape() (231) (5 nodes, cohesion: 0.40)

- getShape()
- stringToShapeType()
- toProtoShape()
- toProtoTimestamp()
- updateShape()

### Community 232 — _VioNumericFieldState() (5 nodes, cohesion: 0.40)

- vio_text_field
- package:flutter/material.dart
- ../theme/vio_spacing.dart
- ../theme/vio_typography.dart
- _VioNumericFieldState()

### Community 233 — uncommittedChanges() (5 nodes, cohesion: 0.40)

- version_control_state
- version_control_bloc.dart
- stagedShapeIds()
- uncommittedChanges()
- VersionControlStatus

### Community 234 — _CommitDialogState() (5 nodes, cohesion: 0.40)

- commit_dialog
- _CommitDialogState()
- ../../bloc/version_control_bloc.dart
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart

### Community 235 — main() (5 nodes, cohesion: 0.40)

- matrix2d_test
- dart:math'
- package:flutter_test/flutter_test.dart
- package:vio_core/vio_core.dart
- main()

### Community 236 — dart:typed_data' (4 nodes, cohesion: 0.50)

- auth.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 237 — AssetViewMode (4 nodes, cohesion: 0.50)

- asset_state
- AssetStatus
- AssetViewMode
- asset_bloc.dart

### Community 238 — main() (238) (4 nodes, cohesion: 0.50)

- integration_test
- package:integration_test/integration_test_driver.dart
- integrationDriver()
- main()

### Community 239 — LoggerExtension (4 nodes, cohesion: 0.50)

- logger
- package:flutter/foundation.dart
- LoggerExtension
- LogLevel

### Community 240 — createGrpcChannel() (240) (4 nodes, cohesion: 0.50)

- grpc_channel_web
- createGrpcChannel()
- package:grpc/grpc_connection_interface.dart
- package:grpc/grpc_web.dart

### Community 241 — package:toml/toml.dart (4 nodes, cohesion: 0.50)

- cargo
- dart:io
- package:path/path.dart'
- package:toml/toml.dart

### Community 242 — dart:typed_data' (242) (4 nodes, cohesion: 0.50)

- project.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 243 — dart:typed_data' (243) (4 nodes, cohesion: 0.50)

- pullrequest.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 244 — Object() (244) (4 nodes, cohesion: 0.50)

- vio_canvas_theme
- package:flutter/material.dart
- vio_colors.dart
- Object()

### Community 245 — createGrpcChannel() (4 nodes, cohesion: 0.50)

- grpc_channel_native
- createGrpcChannel()
- package:grpc/grpc_connection_interface.dart
- package:grpc/grpc.dart

### Community 246 — package:vio_core/vio_core.dart (246) (4 nodes, cohesion: 0.50)

- size_indicator_painter
- dart:typed_data
- package:flutter/material.dart
- package:vio_core/vio_core.dart

### Community 247 — query() (4 nodes, cohesion: 0.50)

- search_state
- search_bloc.dart
- query()
- SearchStatus

### Community 248 — main() (248) (4 nodes, cohesion: 0.50)

- ruler_constants_test
- package:flutter_test/flutter_test.dart
- package:vio_client/src/features/canvas/const/ruler.const.dart
- main()

### Community 249 — dart:typed_data' (249) (4 nodes, cohesion: 0.50)

- branch.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 250 — shape_change.dart (4 nodes, cohesion: 0.50)

- models
- branch_comparison.dart
- pull_request_detail.dart
- shape_change.dart

### Community 251 — dart:typed_data' (251) (4 nodes, cohesion: 0.50)

- common.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 252 — RegisterGeneratedPlugins (4 nodes, cohesion: 0.50)

- GeneratedPluginRegistrant
- FlutterMacOS
- Foundation
- RegisterGeneratedPlugins

### Community 253 — _CanvasRustMixin (4 nodes, cohesion: 0.50)

- canvas_bloc_rust
- _CanvasRustMixin
- .RustEngineService()
- canvas_bloc.dart

### Community 254 — WorkspaceStatus (4 nodes, cohesion: 0.50)

- workspace_state
- CanvasTool
- workspace_bloc.dart
- WorkspaceStatus

### Community 255 — main() (255) (4 nodes, cohesion: 0.50)

- shape_factory_test
- package:flutter_test/flutter_test.dart
- package:vio_core/vio_core.dart
- main()

### Community 256 — ./schema (4 nodes, cohesion: 0.50)

- index
- bun/SQL
- drizzle-orm/bun-sql/drizzle
- ./schema

### Community 257 — util.dart (257) (4 nodes, cohesion: 0.50)

- target
- dart:io
- package:collection/collection.dart
- util.dart

### Community 258 — main() (258) (4 nodes, cohesion: 0.50)

- test_math
- dart:math
- package:flutter/foundation.dart
- main()

### Community 259 — dart:typed_data' (259) (4 nodes, cohesion: 0.50)

- commit.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 260 — package:vio_ui_kit/vio_ui_kit.dart (260) (4 nodes, cohesion: 0.50)

- horizontal_ruler_painter
- package:flutter/material.dart
- package:vio_client/src/features/canvas/const/ruler.const.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 261 — main() (261) (4 nodes, cohesion: 0.50)

- vio_colors_test
- package:flutter_test/flutter_test.dart
- package:vio_ui_kit/vio_ui_kit.dart
- main()

### Community 262 — package:vio_ui_kit/vio_ui_kit.dart (4 nodes, cohesion: 0.50)

- vertical_ruler_painter
- package:flutter/material.dart
- package:vio_client/src/features/canvas/const/ruler.const.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 263 — drizzle-orm/desc (4 nodes, cohesion: 0.50)

- debug-snapshots
- ./db/db
- ./db/schema
- drizzle-orm/desc

### Community 264 — dart:typed_data' (264) (4 nodes, cohesion: 0.50)

- canvas.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 265 — package:vio_ui_kit/vio_ui_kit.dart (265) (4 nodes, cohesion: 0.50)

- theme_section
- package:flutter_bloc/flutter_bloc.dart
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 266 — dart:typed_data' (266) (4 nodes, cohesion: 0.50)

- shape.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 267 — _CanvasHistoryMixin (4 nodes, cohesion: 0.50)

- canvas_bloc_history
- _CanvasHistoryMixin
- ._redoStack()
- canvas_bloc.dart

### Community 268 — package:vio_ui_kit/vio_ui_kit.dart (268) (4 nodes, cohesion: 0.50)

- canvas_status_widgets
- package:flutter/material.dart
- package:vio_client/src/core/core.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 269 — dart:typed_data' (269) (4 nodes, cohesion: 0.50)

- asset.pbjson
- dart:convert'
- dart:core'
- dart:typed_data'

### Community 270 — _getEnvPath() (4 nodes, cohesion: 0.50)

- environment
- _getEnv()
- _getEnvPath()
- dart:io

### Community 271 — package:vio_core/vio_core.dart (271) (3 nodes, cohesion: 0.67)

- hit_test
- package:flutter/rendering.dart
- package:vio_core/vio_core.dart

### Community 272 — framePresetById() (3 nodes, cohesion: 0.67)

- frame_presets
- framePresetById()
- package:equatable/equatable.dart

### Community 273 — _CanvasViewportMixin (3 nodes, cohesion: 0.67)

- canvas_bloc_viewport
- _CanvasViewportMixin
- canvas_bloc.dart

### Community 274 — main() (274) (3 nodes, cohesion: 0.67)

- build_tool
- package:build_tool/build_tool.dart'
- main()

### Community 275 — package:shared_preferences/shared_preferences.dart (3 nodes, cohesion: 0.67)

- preferences_service
- package:flutter/material.dart
- package:shared_preferences/shared_preferences.dart

### Community 276 — main() (276) (3 nodes, cohesion: 0.67)

- test_skia
- tiny_skia::*
- main()

### Community 277 — init_app() (3 nodes, cohesion: 0.67)

- simple
- greet()
- init_app()

### Community 278 — _ResizablePanelHandleState() (3 nodes, cohesion: 0.67)

- resizable_panel_handle
- package:flutter/material.dart
- _ResizablePanelHandleState()

### Community 279 — VioTheme() (3 nodes, cohesion: 0.67)

- theme_state
- theme_bloc.dart
- VioTheme()

### Community 280 — conflicts() (280) (3 nodes, cohesion: 0.67)

- branch_comparison
- conflicts()
- ../../../gen/vio/v1/common.pb.dart'

### Community 281 — presentation/presentation.dart (3 nodes, cohesion: 0.67)

- version_control
- bloc/version_control_bloc.dart
- presentation/presentation.dart

### Community 282 — vector (3 nodes, cohesion: 0.67)

- utils
- string
- vector

### Community 283 — package:protobuf/protobuf.dart' (283) (3 nodes, cohesion: 0.67)

- shape.pbenum
- dart:core'
- package:protobuf/protobuf.dart'

### Community 284 — _CanvasSyncMixin (3 nodes, cohesion: 0.67)

- canvas_bloc_sync
- _CanvasSyncMixin
- canvas_bloc.dart

### Community 285 — package:protobuf/protobuf.dart' (3 nodes, cohesion: 0.67)

- canvas.pbenum
- dart:core'
- package:protobuf/protobuf.dart'

### Community 286 — package:protobuf/protobuf.dart' (286) (3 nodes, cohesion: 0.67)

- pullrequest.pbenum
- dart:core'
- package:protobuf/protobuf.dart'

### Community 287 — _CanvasViewController (3 nodes, cohesion: 0.67)

- canvas_view_controller
- _CanvasViewController
- canvas_view.dart

### Community 288 — package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart (3 nodes, cohesion: 0.67)

- matrix2d
- ../frb_generated.dart
- package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart

### Community 289 — runMain() (3 nodes, cohesion: 0.67)

- build_tool
- src/build_tool.dart'
- runMain()

### Community 290 — AuthStatus (3 nodes, cohesion: 0.67)

- auth_state
- AuthStatus
- auth_bloc.dart

### Community 291 — children() (3 nodes, cohesion: 0.67)

- layer_tree
- children()
- package:vio_core/vio_core.dart

### Community 292 — main() (292) (3 nodes, cohesion: 0.67)

- test_render
- tiny_skia::*
- main()

### Community 293 — CanvasPointerTool (3 nodes, cohesion: 0.67)

- canvas_event
- CanvasPointerTool
- canvas_bloc.dart

### Community 294 — package:protobuf/protobuf.dart' (294) (3 nodes, cohesion: 0.67)

- common.pbenum
- dart:core'
- package:protobuf/protobuf.dart'

### Community 295 — package:vio_ui_kit/vio_ui_kit.dart (295) (3 nodes, cohesion: 0.67)

- ruler.const
- package:flutter/material.dart
- package:vio_ui_kit/vio_ui_kit.dart

### Community 296 — main() (296) (3 nodes, cohesion: 0.67)

- test_transform
- tiny_skia::Transform
- main()

### Community 297 — ShapeChangeType (3 nodes, cohesion: 0.67)

- shape_change
- package:vio_core/vio_core.dart
- ShapeChangeType

### Community 298 — ../../vio_core.dart (3 nodes, cohesion: 0.67)

- shape_factory
- package:flutter/rendering.dart
- ../../vio_core.dart

### Community 299 — asset_bloc.dart (2 nodes, cohesion: 1.00)

- asset_event
- asset_bloc.dart

### Community 300 — auth_bloc.dart (2 nodes, cohesion: 1.00)

- auth_event
- auth_bloc.dart

### Community 301 — grpc_channel_native.dart'
    if (dart.library.html) 'grpc_channel_web.dart (2 nodes, cohesion: 1.00)

- grpc_channel
- grpc_channel_native.dart'
    if (dart.library.html) 'grpc_channel_web.dart

### Community 302 — theme_bloc.dart (2 nodes, cohesion: 1.00)

- theme_event
- theme_bloc.dart

### Community 303 — dart:math' (2 nodes, cohesion: 1.00)

- math_utils
- dart:math'

### Community 304 — flutter/plugin_registry.h (2 nodes, cohesion: 1.00)

- generated_plugin_registrant
- flutter/plugin_registry.h

### Community 305 — version_control_bloc.dart (2 nodes, cohesion: 1.00)

- version_control_event
- version_control_bloc.dart

### Community 306 — package:flutter/material.dart (306) (2 nodes, cohesion: 1.00)

- grid_painter
- package:flutter/material.dart

### Community 307 — AppEnvironment (2 nodes, cohesion: 1.00)

- app_config
- AppEnvironment

### Community 308 — drizzle-kit/Config (2 nodes, cohesion: 1.00)

- drizzle.config
- drizzle-kit/Config

### Community 309 — package:flutter/material.dart (2 nodes, cohesion: 1.00)

- vio_colors
- package:flutter/material.dart

### Community 310 — package:flutter/material.dart (310) (2 nodes, cohesion: 1.00)

- vio_icons
- package:flutter/material.dart

### Community 311 — workspace_bloc.dart (2 nodes, cohesion: 1.00)

- workspace_event
- workspace_bloc.dart

### Community 312 — grpc_canvas_repository.dart (2 nodes, cohesion: 1.00)

- repositories
- grpc_canvas_repository.dart

### Community 313 — search_bloc.dart (2 nodes, cohesion: 1.00)

- search_event
- search_bloc.dart

### Community 314 — widgets/widgets.dart (2 nodes, cohesion: 1.00)

- presentation
- widgets/widgets.dart

### Community 315 — .into_into_dart() (315) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 316 — .sse_decode() (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 317 — auth.pbenum (1 nodes, cohesion: 1.00)

- auth.pbenum

### Community 318 — .sse_encode() (318) (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 319 — desktop_drop-umbrella (1 nodes, cohesion: 1.00)

- desktop_drop-umbrella

### Community 320 — path_provider_foundation-umbrella (1 nodes, cohesion: 1.00)

- path_provider_foundation-umbrella

### Community 321 — .sse_encode() (321) (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 322 — project.pbenum (1 nodes, cohesion: 1.00)

- project.pbenum

### Community 323 — vio_spacing (1 nodes, cohesion: 1.00)

- vio_spacing

### Community 324 — .into_into_dart() (324) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 325 — rust_lib_vio_client-umbrella (1 nodes, cohesion: 1.00)

- rust_lib_vio_client-umbrella

### Community 326 — .sse_decode() (326) (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 327 — dummy_file (1 nodes, cohesion: 1.00)

- dummy_file

### Community 328 — Pods-RunnerTests-dummy (1 nodes, cohesion: 1.00)

- Pods-RunnerTests-dummy

### Community 329 — .into_into_dart() (329) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 330 — .into_into_dart() (330) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 331 — .into_into_dart() (331) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 332 — shared_preferences_foundation-dummy (1 nodes, cohesion: 1.00)

- shared_preferences_foundation-dummy

### Community 333 — flutter_secure_storage_darwin-dummy (1 nodes, cohesion: 1.00)

- flutter_secure_storage_darwin-dummy

### Community 334 — path_provider_foundation-dummy (1 nodes, cohesion: 1.00)

- path_provider_foundation-dummy

### Community 335 — index (1 nodes, cohesion: 1.00)

- index

### Community 336 — .into_into_dart() (336) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 337 — .into_into_dart() (337) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 338 — .into_into_dart() (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 339 — desktop_drop-dummy (1 nodes, cohesion: 1.00)

- desktop_drop-dummy

### Community 340 — resource (1 nodes, cohesion: 1.00)

- resource

### Community 341 — .into_into_dart() (341) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 342 — Pods-RunnerTests-umbrella (1 nodes, cohesion: 1.00)

- Pods-RunnerTests-umbrella

### Community 343 — .sse_decode() (343) (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 344 — .into_into_dart() (344) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 345 — .into_into_dart() (345) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 346 — rust_lib_vio_client-dummy (1 nodes, cohesion: 1.00)

- rust_lib_vio_client-dummy

### Community 347 — .into_into_dart() (347) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 348 — branch.pbenum (1 nodes, cohesion: 1.00)

- branch.pbenum

### Community 349 — .into_into_dart() (349) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 350 — mod (1 nodes, cohesion: 1.00)

- mod

### Community 351 — .sse_encode() (351) (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 352 — asset.pbenum (1 nodes, cohesion: 1.00)

- asset.pbenum

### Community 353 — .into_into_dart() (353) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 354 — flutter_secure_storage_darwin-umbrella (1 nodes, cohesion: 1.00)

- flutter_secure_storage_darwin-umbrella

### Community 355 — file_picker-umbrella (1 nodes, cohesion: 1.00)

- file_picker-umbrella

### Community 356 — mod (356) (1 nodes, cohesion: 1.00)

- mod

### Community 357 — .sse_decode() (357) (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 358 — resolve_symlinks (1 nodes, cohesion: 1.00)

- resolve_symlinks

### Community 359 — selection_handle_metrics (1 nodes, cohesion: 1.00)

- selection_handle_metrics

### Community 360 — shared_preferences_foundation-umbrella (1 nodes, cohesion: 1.00)

- shared_preferences_foundation-umbrella

### Community 361 — mod (361) (1 nodes, cohesion: 1.00)

- mod

### Community 362 — .into_into_dart() (362) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 363 — .sse_encode() (363) (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 364 — index (364) (1 nodes, cohesion: 1.00)

- index

### Community 365 — Pods-Runner-dummy (1 nodes, cohesion: 1.00)

- Pods-Runner-dummy

### Community 366 — lib (1 nodes, cohesion: 1.00)

- lib

### Community 367 — mod (367) (1 nodes, cohesion: 1.00)

- mod

### Community 368 — commit.pbenum (1 nodes, cohesion: 1.00)

- commit.pbenum

### Community 369 — .sse_decode() (369) (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 370 — mod (370) (1 nodes, cohesion: 1.00)

- mod

### Community 371 — .into_into_dart() (371) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 372 — .into_into_dart() (372) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 373 — .into_into_dart() (373) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 374 — .into_into_dart() (374) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 375 — services (1 nodes, cohesion: 1.00)

- services

### Community 376 — Pods-Runner-umbrella (1 nodes, cohesion: 1.00)

- Pods-Runner-umbrella

### Community 377 — .into_into_dart() (377) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 378 — .sse_encode() (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 379 — .sse_decode() (379) (1 nodes, cohesion: 1.00)

- .sse_decode()

### Community 380 — file_picker-dummy (1 nodes, cohesion: 1.00)

- file_picker-dummy

### Community 381 — .into_into_dart() (381) (1 nodes, cohesion: 1.00)

- .into_into_dart()

### Community 382 — .sse_encode() (382) (1 nodes, cohesion: 1.00)

- .sse_encode()

### Community 383 — .into_into_dart() (383) (1 nodes, cohesion: 1.00)

- .into_into_dart()

## 🕳️ Knowledge Gaps

**Isolated nodes** (69):
- index
- index
- vio_spacing
- flutter_secure_storage_darwin-dummy
- flutter_secure_storage_darwin-umbrella
- desktop_drop-umbrella
- desktop_drop-dummy
- Pods-Runner-umbrella
- Pods-Runner-dummy
- shared_preferences_foundation-dummy
- shared_preferences_foundation-umbrella
- Pods-RunnerTests-dummy
- Pods-RunnerTests-umbrella
- file_picker-dummy
- file_picker-umbrella
- path_provider_foundation-dummy
- path_provider_foundation-umbrella
- rust_lib_vio_client-dummy
- rust_lib_vio_client-umbrella
- mod
- _…and 49 more_

**Thin communities** (< 3 nodes): 85 communities

## 💰 Token Cost

| File | Tokens |
|------|--------|
| output | 0 |
| input | 0 |
| **Total** | **0** |

## ❓ Suggested Questions

1. How does 'apps_client_rust_src_rasterizer_tiles_rs' relate to 4 different communities (tile_world_size_at_zoom_1(), update_shape_moves_tiles(), zoom_change_clears_tiles(), TileKey)?
1. How does 'apps_client_rust_src_rasterizer_tiles_rs_evict_distant_tiles' relate to 3 different communities (update_shape_moves_tiles(), TileKey, tile_world_size_at_zoom_1())?
1. How does 'apps_client_rust_src_frb_generated_rs_wire_crate_api_engine_canvasengine_sync_shapes_impl' relate to 3 different communities (wire__crate__api__simple__init_app_impl(), rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine(), .sse_decode() (9))?
1. How does 'apps_client_rust_src_rasterizer_painter_rs_not_rasterizable_inside_clipping_frame_via_frame_id' relate to 3 different communities (set_paint_color(), rasterize_tile_with_zoom(), not_rasterizable_with_shadow())?
1. How does 'apps_client_rust_src_frb_generated_rs_wire_crate_api_engine_canvasengine_query_visible_impl' relate to 3 different communities (wire__crate__api__simple__greet_impl(), rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine(), .sse_decode() (9))?
1. How does 'apps_client_rust_src_frb_generated_rs_usize_sse_decode' relate to 3 different communities (wire__crate__api__simple__init_app_impl(), wire__crate__api__simple__greet_impl(), .sse_decode() (9))?
1. How does 'apps_client_rust_src_frb_generated_rs_wire_crate_api_engine_canvasengine_hit_test_rect_impl' relate to 3 different communities (rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerCanvasEngine(), wire__crate__api__simple__greet_impl(), .sse_decode() (9))?

---
_Generated by graphify-rs_
