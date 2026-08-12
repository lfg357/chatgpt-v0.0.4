# 《时层钻探局》技术与测试规格

> 文档版本：1.0  
> 目标：让 Codex Agent 在不临时决定架构、接口、失败语义和验收标准的情况下实施。  
> 产品阶段见 [开发主计划](DEVELOPMENT_PLAN.md)，内容 ID 与数值见 [游戏内容圣经](CONTENT_BIBLE.md)。

## 1. 技术基线

- Godot `4.7.stable`，强类型 GDScript。
- 物理帧 60 Hz；设计分辨率 640×360，默认窗口 1280×720，`canvas_items` 整数缩放。
- 2D 像素资产使用 Nearest、关闭 MipMap、启用像素吸附；UI 字体允许非整数内部缩放，但最终控件位置取整。
- Windows Desktop 为首要验收平台，Web 为兼容构建。
- 禁止 GDExtension、平台原生 DLL、运行时网络、线程必需逻辑和只支持 Windows 的存档路径。
- 调试与测试代码由 `OS.is_debug_build()` 和 feature tag 隔离，发布构建不可显示开发面板。

## 2. 目录与依赖方向

```text
res://
  src/
    core/          # 状态、事件、存档、内容库
    domain/        # 纯逻辑：经济、回声、生成、结算
    gameplay/      # 钻机、地形、危险、生物、相机
    ui/            # 页面、HUD、组件
    tools/         # 调试面板、资产生成、模拟器
  content/
    definitions/   # .tres 内容定义
    maps/          # 手工房间模块和保底地图
    localization/  # 中英文翻译表
  assets/
    sprites/ audio/ fonts/ shaders/
  scenes/
    boot/ hub/ dive/ ui/ benchmarks/
  tests/
    unit/ integration/ simulation/ fixtures/
  docs/
```

依赖只能单向：`core → domain → gameplay/ui`。`domain` 不得引用场景、输入或渲染节点；UI 只能通过服务方法和信号改变状态。

## 3. Autoload 与状态机

固定 Autoload：

| 名称 | 职责 | 禁止职责 |
|---|---|---|
| `AppState` | 应用状态机、当前档案、流程信号 | 计算经济和操纵场景子节点 |
| `ContentDB` | 加载、索引、校验定义资源 | 修改玩家进度 |
| `SaveService` | 档案加载、原子保存、迁移和备份 | 决定游戏规则 |
| `AudioService` | 音频总线、循环、设置 | 持有玩法状态 |
| `InputService` | 最近设备、重绑定和图标族 | 直接操纵钻机 |
| `SceneRouter` | 异步场景切换与遮罩 | 保存游戏进度 |

`EconomyService`、`EchoService`、`MapGenerator` 为普通域对象，由档案会话持有，避免全局状态污染测试。

应用状态枚举：

```gdscript
enum AppMode { BOOT, MAIN_MENU, PROFILE_SELECT, HUB, DIVE, RESULTS, SOFT_RESET }
```

状态切换必须经过 `AppState.request_transition(target, payload)`；非法切换返回错误，不静默执行。

## 4. 数据定义与公共接口

### 4.1 定义资源

所有内容资源继承 `ContentDef`：

```gdscript
class_name ContentDef extends Resource
@export var id: StringName
@export var name_key: StringName
@export var description_key: StringName
@export var content_version: int = 1
@export var enabled: bool = true
```

具体类型：`LayerDef`、`RoomModuleDef`、`MineralDef`、`HazardDef`、`CreatureDef`、`ModuleDef`、`RelicDef`、`FacilityDef`、`TechDef`、`ContractDef`、`ChronalLawDef`、`ArchiveDef`。

内容 ID 永不复用。删除内容时保留 tombstone 迁移条目，不把旧 ID 指向不同物品。

### 4.2 运行类型

```gdscript
class_name RunConfig extends Resource
var layer_id: StringName
var contract_id: StringName
var module_ids: Array[StringName]       # 固定 5 项
var relic_id: StringName                # 可为空
var seed: int
var generator_version: int
var timeline_index: int

class_name CargoEntry extends Resource
var mineral_id: StringName
var count: int
var scrap_value: int
var data_value: int
var damaged_count: int

class_name RouteSample extends Resource
var time_ms: int
var position: Vector2
var aim_angle: float
var flags: int                          # drill/boost/damage/overheat/tool

class_name RunResult extends Resource
var run_id: String
var config: RunConfig
var success: bool
var failure_reason: StringName
var duration_ms: int
var cargo: Array[CargoEntry]
var damage_taken: int
var overheat_count: int
var emergency_collision_count: int
var discovery_ids: Array[StringName]
var route_samples: Array[RouteSample]
var contract_progress: Dictionary
var performance_summary: Dictionary
```

### 4.3 回声类型

```gdscript
class_name EchoRecord extends Resource
var schema_version: int = 1
var route_encoding_version: int = 1
var generator_version: int
var content_version: int
var echo_id: String
var layer_id: StringName
var seed: int
var duration_ms: int
var compressed_path: PackedByteArray
var cargo_ledger: Dictionary
var stability: float
var loadout_hash: String
var is_pinned: bool
var created_unix: int
```

旧回声无法解码时：保留 `cargo_ledger`、`stability` 和产量；投影室改用简化环形动画并显示“旧式回声”，不得删除或清零。

### 4.4 存档类型

```gdscript
class_name SaveSnapshot extends RefCounted
var schema_version: int = 1
var content_version: int = 1
var profile_id: int
var created_unix: int
var updated_unix: int
var economy: Dictionary
var unlocks: Dictionary
var facilities: Dictionary
var modules: Dictionary
var echoes: Array[Dictionary]
var timeline: Dictionary
var archives: Array[StringName]
var tutorial: Dictionary
var statistics: Dictionary
```

设置不属于档位，使用独立的全局 `AppSettings`：

```gdscript
class_name AppSettings extends RefCounted
var schema_version: int = 1
var locale: String
var display: Dictionary
var audio: Dictionary
var accessibility: Dictionary
var input_bindings: Dictionary
var local_playtest_logging: bool = true
```

`SaveSnapshot` 中 Dictionary 的固定键：

```text
economy: { scrap:int, core:int, data:int, chronoshard:int }
unlocks: { layer_ids:Array, blueprint_ids:Array, relic_ids:Array, law_ids:Array }
facilities: { facility_id:String -> level:int }
modules: { module_id:String -> { unlocked:bool, level:int } }
timeline: {
  index:int,
  active_law_id:String,
  pending_law_choice:bool,
  pending_law_options:Array[String],
  pinned_echo_ids:Array[String],
  total_resets:int
}
tutorial: { completed_step_ids:Array[String], skipped:bool }
statistics: {
  total_runs:int, successful_runs:int, failed_runs:int,
  total_dive_seconds:int, deepest_layer_id:String,
  resources_mined:Dictionary, archives_found:int
}
```

缺失键由当前 schema 的默认值补齐；类型错误视为存档损坏并尝试备份。资源、设施和模块不得出现负数等级或负数余额。

### 4.5 服务接口

```gdscript
AppState.start_run(config: RunConfig) -> Result
AppState.complete_run(result: RunResult) -> Settlement

ContentDB.load_all() -> ValidationReport
ContentDB.get_def(id: StringName, expected_type: StringName) -> ContentDef

MapGenerator.generate(layer: LayerDef, seed: int) -> GeneratedMap
MapValidator.validate(map: GeneratedMap) -> GenerationReport

EconomyService.quote_upgrade(id: StringName, level: int) -> int
EconomyService.purchase_upgrade(id: StringName) -> PurchaseResult
EconomyService.apply_run_result(result: RunResult) -> Settlement
EconomyService.simulate(minutes: int, strategy_id: StringName, seed: int) -> EconomyReport

EchoService.can_register(result: RunResult) -> ValidationResult
EchoService.create_record(result: RunResult) -> EchoRecord
EchoService.register(record: EchoRecord, slot: int) -> Result
EchoService.simulate_elapsed(seconds: int) -> Dictionary

SaveService.load_profile(slot: int) -> LoadResult
SaveService.save_profile(slot: int, reason: StringName) -> Result
SaveService.restore_backup(slot: int) -> Result
SaveService.migrate(raw: Dictionary) -> MigrationResult
```

返回值使用统一结果对象：

```gdscript
class_name Result extends RefCounted
var ok: bool
var code: StringName
var message_key: StringName
var data: Variant

class_name Settlement extends RefCounted
var banked_resources: Dictionary
var lost_resources: Dictionary
var contract_rewards: Dictionary
var new_unlock_ids: Array[StringName]
var archive_ids: Array[StringName]

class_name GeneratedMap extends RefCounted
var layer_id: StringName
var seed: int
var generator_version: int
var grid: PackedInt32Array
var grid_width: int
var grid_height: int
var room_instances: Array[Dictionary]
var spawn_cell: Vector2i
var exit_cell: Vector2i
var objective_cells: Array[Vector2i]
var topology_hash: String

class_name GenerationReport extends RefCounted
var valid: bool
var error_codes: Array[StringName]
var reachable_required_nodes: int
var required_nodes: int
var hazard_budget: int
var retry_count: int
var generation_time_ms: float

class_name EconomyReport extends RefCounted
var strategy_id: StringName
var seed_count: int
var milestone_minutes: Dictionary
var resource_curves: Dictionary
var failure_recovery_minutes: float
var build_scores: Dictionary
var violations: Array[StringName]
```

`ValidationReport`、`ValidationResult`、`PurchaseResult`、`LoadResult`、`MigrationResult` 复用 `Result`，其 `data` 分别承载错误列表、购买后等级、`SaveSnapshot` 或迁移后的字典。域服务不得用弹窗处理错误。

### 4.6 全局信号

```text
app_mode_changed(previous, current)
profile_loaded(profile_id)
save_failed(reason_code)
run_started(config)
run_completed(result, settlement)
resource_changed(resource_id, old_value, new_value)
upgrade_purchased(content_id, new_level)
echo_registered(slot, echo_id)
soft_reset_completed(timeline_index, law_id)
input_device_changed(device_family)
language_changed(locale)
```

## 5. 钻机物理与输入

### 5.1 输入动作

Godot InputMap 固定动作：

```text
move_left, move_right, move_up, move_down
aim_left, aim_right, aim_up, aim_down
drill, use_tool, boost, sonar, place_beacon, recall
pause, ui_accept, ui_cancel, ui_tab_left, ui_tab_right
```

鼠标瞄准不直接写入域状态；控制器计算统一的 `ControlFrame`：移动向量、瞄准向量、按下/保持/释放位掩码。右摇杆长度低于死区时保持上次有效瞄准方向。

默认死区 0.18，可调 0.10～0.35。支持键盘、鼠标按钮和手柄按钮重绑定；保留“恢复默认”。冲突绑定必须提示并要求替换或取消。

### 5.1.1 HUD 与基地布局

- HUD 左上：耐久、能量；上中：热量条与过热状态；右上：合同目标和当前深度。
- HUD 左下：工具图标、弹药/冷却；下中：货舱与连击；右下：声呐、信标和撤离提示。
- 屏幕中心只显示小型瞄准点和交互提示；任何永久 HUD 不得覆盖钻机前方 120×90 px 安全区。
- 基地页面顶部为四资源条，左侧为固定导航，中央为基地设施，右侧为当前目标和回声摘要。
- 640×360 下所有主要页面不得依赖滚动才能访问确认/取消；列表可滚动，但操作栏固定。

### 5.1.2 相机

- 基础缩放 1.0，视口对应 640×360 设计像素。
- 跟随平滑系数 8.0；向瞄准方向最多前视 48 px，向移动方向额外前视 16 px。
- 相机不得越过地图边界；小房间居中并允许黑边。
- 震屏采用 trauma：普通采矿 0.05、碰撞 0.2、爆破 0.35、损毁 1.0；最大位移 6 px、最大旋转 0.5°、每秒衰减 1.8。
- 设置中的震屏百分比线性缩放 trauma 输出；0% 时位移和旋转都为零。

### 5.2 物理常量

以内容圣经为初始调参源。实现必须满足：

- `CharacterBody2D` 在 `_physics_process` 中更新，禁止基于渲染帧积分。
- 推进速度使用 `move_toward`，普通最大速度 150 px/s，重力终端速度 220 px/s。
- 冲刺 0.35 秒、目标速度 260 px/s、冷却 1.2 秒；冲刺过程仍进行碰撞检测。
- 钻头前方 18 px、60° 锥形采样；每物理帧最多请求移除 4 块瓦片。
- 钻探、碰撞和爆破先生成域事件，再由表现层播放音效、粒子和震动。
- 暂停时物理、运行计时、热量、回声和本地事件时间全部停止。

### 5.3 热量与能量

- 能量范围 0～100；不允许负值。
- 无耗能动作 0.75 秒后开始每秒恢复 12。
- 钻探每秒热量 +12；冲刺期间额外 +20。
- 非钻探基础散热每秒 18。
- 热量达到 100 触发 2 秒停机；停机期间不可钻探，仍可低速移动和使用撤离。
- 热量 70、85、100 分别触发 UI、音频和画面三级反馈；闪光强度受可访问性设置限制。

## 6. 可破坏地形

### 6.1 数据结构

- 逻辑瓦片 16×16 px。
- 世界按 32×32 瓦片分块，每块维护前景 TileMapLayer、背景层、碰撞脏标记和活动对象列表。
- 不可破坏边界至少 2 瓦片厚。
- 地图域数据是整数网格；TileMap 是表现和碰撞投影，不作为唯一真相源。

### 6.2 修改队列

钻探或爆破调用 `TerrainService.request_damage(cell, amount, source)`：

1. 更新网格耐久并记录事件。
2. 达到零时将瓦片加入当前帧删除集合。
3. 同一单元格请求去重。
4. 每个物理帧统一提交视觉更新。
5. 被修改分块标记碰撞脏；每物理帧最多重建 2 个分块，其余排队。
6. 等待碰撞更新的已删除瓦片使用临时无碰撞遮罩，防止“幽灵墙”。

碎片、尘土、火花、伤害数字和声波全部对象池化。不得为每个被破坏瓦片永久生成 Node。

### 6.3 爆破

- 爆破半径 32 px，以整数网格圆形掩码选取瓦片。
- 对矿物先标记爆破损伤，再结算；灯核晶数据价值减半。
- 对生物只发送惊扰/撤退事件，不产生装备掉落。
- 一次爆破最多修改 48 块瓦片；超过时按距离排序截断。

## 7. 地图生成

### 7.1 房间模块

`RoomModuleDef` 必含：尺寸、连接锚点、标签、层级、风险值、矿物预算、危险预算、是否允许旋转/镜像。模块场景不得包含运行期随机逻辑。

生成步骤：

1. 使用 `RandomNumberGenerator` 和 `seed`。
2. 放置入口与出口，构造 6～10 个节点的有向主路径。
3. 主路径至少放置一个补给房；科技解锁前可由层定义覆盖。
4. 追加 0～3 条风险支路，试玩固定首次种子使用脚本化数量。
5. 根据房间预算放置矿物、危险、生物和遗迹。
6. 构建整数网格并洪泛检查入口、出口、补给和目标可达。
7. 检查入口 4 格内无伤害危险，关键通道宽度至少 2 格。
8. 验证失败最多重试 3 次；仍失败加载每层固定保底地图。

`generator_version` 从 1 开始；任何改变相同种子结果的算法修改必须递增版本。存档和回声同时保存版本。

### 7.2 决定性边界

相同 Godot 主版本、`generator_version`、内容版本、地层和种子必须生成相同的拓扑哈希。物理运动不要求跨平台逐帧决定性；回声因此只记录路径和账本，不重演物理。

## 8. 回声记录与生产

### 8.1 采样与压缩

- 只在 `DIVE` 且未暂停时以 10 Hz 采样。
- 首点、末点、工具事件、伤害、过热和方向突变点必须保留。
- 普通相邻点距离 <4 px 且角度变化 <5° 时合并。
- 编码使用相对时间和相对位置的有符号整数；每条路线最大 64 KB。
- 超过上限时提高普通点简化阈值，关键事件点不得删除。

### 8.2 登记

只有 `success == true`、持续时间 ≥30 秒、货物价值 >0 且路线可编码时可登记。覆盖前显示：

- 每分钟废料、数据与核心期望值。
- 稳定度。
- 相比当前槽位的百分比差异。
- 对应地层、构筑和路线缩略图。

回声不在当前物理地图中工作。基地投影室显示简化路径；只有加载完全相同种子和生成器版本的历史地图时才允许显示完整幽灵覆盖。

### 8.3 时间推进

- 在线每秒结算一次，但 UI 可平滑动画。
- 离线使用 Unix 秒差，不使用本地时区或夏令时。
- 时间差 <0 记为 0；超过上限截断。
- 离线收益在加载后先显示预览；确认后在同一个内存快照中同时加入收益并更新 `last_seen_unix`，原子保存成功后才更新 UI。
- 保存失败则档案内存保持加载前状态并允许重试；不得只推进时间而未发放收益，也不得多次领取同一区间。

## 9. 经济与软重置

经济规则以内容圣经为准；整数资源使用 64 位整数并在 UI 层格式化。

购买事务：校验内容存在、已解锁、等级未满、前置满足和资源足够；在内存副本扣款并升级，通过不变量校验后一次提交，再立即保存。失败不得部分扣款。

失败结算：发现和教程进度保留；未入库货物的废料、数据分别乘 0.5 后向下取整；核心视为密封物品，失败时全部丢失；失败路线不可登记。

软重置事务：

1. 生成保留/删除预览。
2. 玩家选择最多 2 条已解锁固定能力的回声。
3. 创建重置前备份。
4. 生成新快照并运行不变量校验。
5. 新快照进入 `pending_law_choice = true`，原子提交；失败恢复旧快照。
6. 玩家选择一个时间法则并支付 3 时间碎片，再次原子保存并清除 `pending_law_choice` 后才允许返回基地。
7. 若选择法则前关闭游戏，下次加载必须直接回到法则选择页，不能进入其他页面或再次获得重置奖励。

保留集合固定为：数据余额、科技、模块解锁、遗物发现、设施等级、档案、统计、基地外观、已选法则和最多 2 条固定回声。清除/重置集合固定为：废料、核心、合同进度、地图种子、未固定回声、当前运行；所有已解锁模块等级回到 L1。时间碎片在法则事务中先奖励 3、再消费 3，最终余额为原余额。

## 10. 存档、退出与兼容

### 10.1 文件

每个档位：

```text
user://profiles/slot_N/save.json
user://profiles/slot_N/save.bak.json
user://profiles/slot_N/save.tmp.json
```

全局设置使用：

```text
user://settings/settings.json
user://settings/settings.bak.json
user://settings/settings.tmp.json
```

JSON 根对象包含：`schema_version`、`content_version`、`payload`、`payload_sha256`。校验摘要只用于发现损坏，不用于防作弊。

### 10.2 原子保存

1. 序列化内存快照并校验所有不变量。
2. 写入临时文件并关闭句柄。
3. 重新读取临时文件、解析并核对摘要。
4. 主文件有效时复制为备份。
5. 用临时文件替换主文件。
6. Web 环境请求文件系统同步；同步失败向玩家显示非阻塞错误并保留内存状态。

启动加载顺序：主文件 → 备份 → 新档。检测到比当前实现更高的 `schema_version` 时禁止覆盖，显示“存档来自较新版本”。

档案选择固定 3 个槽位，显示总时长、当前时间线、最深地层和最后保存时间。试玩版不支持重命名。删除档案需要进入二次确认并长按 2 秒；删除主档和备份但不删除全局设置或本地试玩日志。删除失败不得留下“空槽但文件仍在”的假状态。

### 10.3 保存时机

- 新建档案。
- 结算完成。
- 购买与设施升级。
- 登记、覆盖、固定回声。
- 离线收益入账。
- 修改设置或输入绑定时保存全局设置文件，不写入当前档位。
- 软重置前备份与提交后。

下潜中不保存地图和货物。主动离开下潜必须确认；确认、崩溃或 Web 刷新均视为放弃本次未结算货物。

### 10.4 迁移

每个版本使用独立纯函数 `migrate_vN_to_vN_plus_1`，不得就地修改输入字典。迁移必须可重复执行、保留未知安全字段，并对已删除内容 ID 应用 tombstone：

- 已删除模块：退还该模块累计废料与核心，移除装备引用。
- 已删除遗物：标记为已发现并补偿 40 数据。
- 旧回声内容缺失：保留账本和产量，使用旧式动画。
- 无法迁移：保持原文件不变，提供备份恢复和错误码。

## 11. 本地化、设置与可访问性

- 所有显示文本通过 `tr(key)`；脚本和场景不得写最终显示字符串。
- CI/验证比较中英键集合，缺失或额外键均失败。
- 数字、百分比、秒数和按键名称通过格式化服务生成。
- 默认语言跟随系统；不支持时使用简体中文。
- 固定使用 Fusion Pixel Font `12px proportional zh_hans` 作为主 UI 字体，来源 `https://github.com/TakWolf/fusion-pixel-font`，锁定发行版 `v2026.07.20`；许可证按上游 OFL-1.1 原文随项目保存。数字表格允许使用同发行版 `12px monospaced`。若该发行版无法取得，必须向用户请求变更，不得由 Agent 自选另一字体。

设置默认值：

| 设置 | 默认 |
|---|---|
| 主音量/音乐/音效 | 80% / 70% / 85% |
| 全屏 | 关闭 |
| 垂直同步 | 开启 |
| 震屏 | 70% |
| 闪光强度 | 60% |
| 手柄震动 | 开启 |
| 手柄死区 | 0.18 |
| 钻探模式 | 按住 |
| 语言 | 自动 |

设置文件采用与档案相同的临时文件、摘要和备份流程。设置损坏时只恢复设置备份或默认设置，不读取、重写或重置游戏档案。失去窗口焦点或手柄断开时自动暂停；Web 恢复焦点前不得接收残留按键。

## 12. 程序美术与音频管线

### 12.1 色板

全局固定 24 色；初稿 RGB：

```text
#10141F #1B2638 #2F3A4C #53606F #7A8791 #C3CCD0
#F2E6CF #C98C55 #A65B45 #703B3B #D3A45C #F0D77A
#426B69 #55917F #73D1C8 #A8E0C8 #274C67 #427AA1
#8FC7FF #605080 #8A68A6 #D59CFF #7D334E #D85B6A
```

每个地层可使用其中 12～16 色，不新增未登记色。主光源统一来自左上；外轮廓 1 像素，交互高亮不依赖纯颜色变化。

### 12.2 资产生成

- 使用 headless 可运行的 `artgen` 工具读取像素矩阵、色板索引和帧元数据，输出 PNG 与 SpriteFrames 资源。
- 输出必须可重复：相同源描述产生相同 SHA-256。
- 生成文件不得手工修改；修改源描述后重新生成。
- 每次生成自动创建 1× 精灵表和 4× 最近邻预览。
- 建立“黄金样板”截图：钻机、工业地层、矿物、危险、HUD 和主要粒子同屏。后续资产必须与其光源、轮廓、饱和度一致。

### 12.3 音频

- 钻头包含启动、稳定循环、岩石接触、矿物接触、过热、停机六层；循环切换使用 50～100 ms 淡入淡出。
- 程序生成 UI、矿物和警告音；基地、工业、深层三段音乐须可无缝循环。
- 只有质量门失败时才引入 CC0 音效；引入前记录来源与许可证。
- Web 首次用户交互前不自动播放音频；交互后恢复正确总线状态。

## 13. 调试、平衡与试玩工具

调试构建提供 `F10` 开发面板：

- 选择地层、种子、房间和合同。
- 传送至出口、补给、遗迹和层核心。
- 添加或清零资源；解锁指定内容。
- 调整耐久、能量、热量、货舱和连击。
- 强制成功、失败、过热、软重置和存档损坏模拟。
- 快进回声 1 分钟、1 小时、4 小时。
- 显示主路径、风险预算、连接锚点、碰撞分块、脏队列和对象池数量。
- 导出当前 `RunResult`、地图哈希和性能摘要。

经济模拟器固定策略：保守、安全撤离；平衡、完成合同；激进、优先支路；回声优化、重复最高效率路线。每种策略运行至少 100 个种子并输出阶段产出、购买时间、失败恢复和构筑排名。

## 14. 本地试玩日志

只写本地 `user://playtest_events.jsonl`，不上传网络。玩家可在设置中关闭记录；默认开启并在首次启动说明“仅保存在本机”。

事件：

```text
session_start, session_end, tutorial_step
run_start, room_enter, mineral_mined, damage_taken, overheat
run_success, run_failure, run_abandon
upgrade_purchase, facility_upgrade, tech_unlock
echo_preview, echo_register, echo_replace
soft_reset, setting_change, performance_summary
```

共同字段：事件版本、匿名本地会话 ID、Unix 时间、游戏版本、档位、输入设备、语言。不得记录用户名、系统路径或联网标识。

“导出试玩报告”生成汇总 CSV 与原始 JSONL 副本，包含教学耗时、下潜次数、成功率、二次下潜、升级顺序、回声使用和帧时间。

## 15. 原生测试框架

不依赖第三方测试插件。`res://tests/test_runner.gd` 自动发现 `test_*.gd`，支持：

- `before_all/after_all`
- `before_each/after_each`
- 同步测试和带超时的异步测试
- `assert_true/equal/near/contains/signal_emitted`
- 每用例隔离随机数、临时目录和域服务实例
- JUnit 风格 XML 与控制台摘要
- 任一失败、未捕获错误、超时或零用例发现均返回非零退出码

测试框架自测必须证明：失败退出码、清理钩子、异常捕获、超时、零用例和用例计数均正确。

统一入口：

```powershell
$env:GODOT_BIN='C:\Users\AdminLFG\AppData\Local\Programs\Godot\Godot_v4.7-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File tools\verify.ps1
```

验证顺序：导入与脚本解析 → 框架自测 → 单元测试 → 集成测试 → 内容校验 → 1000 种子 → 经济模拟冒烟 → 性能冒烟。

## 16. 单元测试清单

### 16.1 物理与输入

- `test_energy_delay_and_clamp`
- `test_heat_shutdown_and_recovery`
- `test_pause_freezes_all_run_clocks`
- `test_boost_respects_collision`
- `test_aim_keeps_last_direction_inside_deadzone`
- `test_rebind_conflict_requires_resolution`
- `test_controller_disconnect_pauses`
- `test_camera_lookahead_and_map_bounds`

### 16.2 地形与生成

- `test_tile_damage_is_deduplicated_per_frame`
- `test_removed_tile_has_no_ghost_collision`
- `test_explosion_caps_changed_cells`
- `test_chunk_rebuild_budget`
- `test_generation_same_seed_same_hash`
- `test_generation_all_required_nodes_reachable`
- `test_safe_spawn_has_no_damage_hazard`
- `test_generator_falls_back_after_three_failures`

### 16.3 经济与内容

- `test_upgrade_cost_monotonic`
- `test_purchase_is_atomic`
- `test_failure_loses_half_flooring`
- `test_failure_loses_all_unbanked_cores`
- `test_combo_window_and_cap`
- `test_all_content_ids_unique_and_references_valid`
- `test_each_build_has_defined_cost_and_unlock`
- `test_localization_key_sets_equal`

### 16.4 回声

- `test_route_keeps_first_last_and_event_points`
- `test_route_size_is_bounded`
- `test_route_round_trip_error_under_four_pixels`
- `test_only_successful_run_can_register`
- `test_stability_bounds`
- `test_echo_yield_formula`
- `test_offline_negative_and_four_hour_cap`
- `test_offline_interval_cannot_claim_twice`
- `test_old_echo_keeps_ledger_when_path_decoder_missing`

### 16.5 存档与重置

- `test_save_round_trip`
- `test_corrupt_primary_restores_backup`
- `test_failed_temp_validation_preserves_primary`
- `test_newer_schema_is_never_overwritten`
- `test_migration_is_idempotent`
- `test_deleted_content_refunds_and_unequips`
- `test_soft_reset_keep_and_clear_sets`
- `test_soft_reset_failure_restores_previous_snapshot`
- `test_pending_law_choice_resumes_after_restart`
- `test_settings_corruption_does_not_reset_progress`
- `test_global_settings_are_shared_across_profiles`
- `test_font_files_have_recorded_ofl_license`
- `test_profile_delete_never_deletes_global_settings`
- `test_core_event_failure_resets_without_ending_run`

## 17. 集成与场景测试

自动化流程及固定测试名：

1. `test_flow_new_profile_tutorial_upgrade`：新建档案、完成固定教学种子、结算并购买升级。
2. `test_flow_first_echo_registration`：第二次成功下潜、建立投影室并登记首条回声。
3. `test_flow_echo_compare_cancel_and_replace`：更差路线显示负差异并取消；更好路线覆盖后收益更新。
4. `test_flow_destroyed_run_settlement`：下潜损毁，验证 50% 货物、全部未入库核心丢失且无回声。
5. `test_flow_abandon_run_discards_only_run_state`：放弃下潜，验证基地资源不变、运行货物清零。
6. `test_flow_complete_three_layers_and_reset`：完成三个层核心并执行一次软重置。
7. `test_flow_pending_law_choice_restart`：重置后未选法则即关闭，重启后只能继续法则选择且奖励不重复。
8. `test_flow_restart_preserves_profile_and_global_settings`：重启进程后读取相同档案、设置、回声和法则。
9. `test_flow_corrupt_and_newer_save_handling`：主存档损坏时恢复备份；高版本存档只读失败且不覆盖。
10. `test_flow_localization_longest_text_screens`：中英文运行全部页面并截取最长文本。
11. `test_flow_keyboard_and_controller_to_first_echo`：键鼠和手柄分别完成新档到首条回声流程。
12. `test_flow_web_refresh_persistence`：Web 模拟刷新后保留最近一次基地保存，丢弃未结算下潜。
13. `test_flow_scene_cycle_has_no_growth`：重复进入/退出下潜 100 次，节点和内存不持续增长。
14. `test_flow_offline_claim_is_atomic`：模拟领取期间保存失败，验证时间和奖励均不提交；重试只领取一次。

## 18. 模拟、性能与视觉验收

### 18.1 种子测试

每个地层至少测试 1000 个种子：全部主路径可达、关键目标存在、入口安全、危险预算合法、无模块重叠。报告记录失败种子、重试次数、生成耗时 P95 和拓扑哈希。

### 18.2 性能基准

固定场景：1280×720、500 活跃可破坏瓦片、每秒删除 40 块、200 粒子、20 环境实体、3 条回声动画、固定相机路径；预热 10 秒，采样 120 秒。

| 指标 | Windows | Web |
|---|---:|---:|
| 帧时间 P95 | ≤16.7 ms | ≤20 ms |
| 帧时间 P99 | ≤25 ms | ≤33 ms |
| 单帧地形重建峰值 | ≤4 ms | ≤6 ms |
| 生成单图 P95 | ≤250 ms | ≤400 ms |
| 30 分钟内存增长 | ≤10% | ≤15% |
| 构建内存目标 | <400 MB | <512 MB |

报告必须记录 CPU、GPU、内存、系统、构建类型和 Godot 版本。无法在目标硬件验证时不得声称通过，只能标记“当前开发机通过”。

### 18.3 视觉快照

至少覆盖：三层黄金场景、五种热量状态、三种损伤状态、全部页面中英文、键鼠/手柄图标、四档震屏/闪光设置、所有设施等级。快照检查模糊、半像素、缺图、遮挡、文本溢出和焦点不可见。

## 19. 手工边缘场景

- 钻头贴地图边界时持续钻探、冲刺和爆破。
- 一次爆破跨越多个碰撞分块。
- 同时按钻探、工具、撤离与暂停。
- 暂停和失焦时热量、计时、回声完全停止。
- 手柄震动过程中断开并改用键鼠。
- 打开确认弹窗后切换语言。
- 货舱正好满、超额采集、资源接近 64 位边界。
- 回声路径为空、单点、损坏、旧编码或引用已删除矿物。
- 系统时间前跳、后退、跨时区和超过 4 小时。
- 磁盘空间不足、目录只读、临时文件写入失败。
- Web 首次音频未解锁、刷新、浏览器后退和存储不可用。
- 快速连续购买、覆盖回声和切换页面。
- 软重置确认中断、保存失败和恢复旧快照。

## 20. 发布门槛

- Headless 导入和所有脚本解析无错误。
- 测试运行器发现的用例数量不少于 55；全部通过。
- 每层 1000 个种子通过；无不可达或入口伤害。
- 经济模拟四种策略均能在 60～90 分钟到达时间核心，无负资源、死锁或超过 20% 的绝对最优构筑。
- Windows 和 Web 在已记录硬件上达到性能阈值。
- 新档、失败、回声、离线、软重置、备份恢复和高版本存档场景通过。
- 键鼠和手柄都能完成全部菜单与核心流程。
- 中英文无缺键、硬编码最终文本或阻断级溢出。
- 无灰盒、占位图标、未登记第三方资产或发布构建中的开发面板。
- 至少 3 人 5 次试玩满足主计划中的手感门和回声认知门；未满足时构建只能标为技术候选版。

## 21. 导出预设与本地验收产物

导出模板必须与 Godot `4.7.stable` 完全匹配。模板不存在时发起授权卡下载官方模板，不使用其他版本或第三方重打包模板。

### Windows Desktop

- 预设名：`Windows Desktop RC`
- 架构：x86_64
- 构建类型：release，无调试控制台
- 输出：`build/windows/TimeStrataDrill.exe` 与相邻 `.pck`
- 窗口默认 1280×720，可调整、可无边框全屏
- 发布前扫描，确认不包含测试、基准场景和开发面板入口

### Web

- 预设名：`Web RC`
- 单线程 WebAssembly，不要求 Cross-Origin Isolation
- 禁用 PWA、扩展支持和线程；启用 WebGL2 兼容渲染
- 输出：`build/web/index.html` 及 Godot 生成的相邻资源
- 页面画布按窗口缩放，保持 16:9 和整数像素优先；非整数窗口允许黑边
- 本地验收必须通过 HTTP 服务打开，不使用 `file://`
- Web 首次交互解锁音频；刷新后验证 IndexedDB 持久化

构建脚本先运行完整验证，再清空对应构建目标中的旧生成物并导出。只允许清理 `build/windows` 和 `build/web` 两个已解析、已验证位于工程内的目录。

## 22. Codex 任务验收格式

每个实施任务结束时必须提供：

```text
完成目标：
修改范围：
公共接口变化：
内容 ID 或存档版本变化：
执行的测试与结果：
视觉/性能检查：
已知风险：
下一任务的入口条件：
```

任何公共接口、内容 ID、生成器版本、路线编码版本或存档版本变化，都必须同步更新三份文档及相应迁移测试。
