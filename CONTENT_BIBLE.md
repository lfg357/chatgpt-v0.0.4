# 《时层钻探局》游戏内容圣经

> 文档版本：1.0  
> 本文定义试玩候选版的全部游戏内容、初始数值、解锁条件和玩家文案。  
> 实现流程见 [开发主计划](DEVELOPMENT_PLAN.md)，数据结构与测试见 [技术与测试规格](TECHNICAL_TEST_SPEC.md)。

## 1. 世界观与文案基调

玩家是“时层修复员”，受命重启一座失去联系的文明档案站。地下并非普通岩层，而是不同时代被压缩后留下的时间地层。钻探不是掠夺：每一件矿物和遗物都会帮助基地复原文明如何生活、生产和犯错的记录。

文案原则：

- 温暖、克制、略带幽默，不嘲笑失败。
- 公司和工业词汇用于建立世界，不进行密集职场讽刺。
- 每条说明先说作用，再说世界观。
- 中文单条 UI 正文不超过 54 字；英文不超过 110 个字符。
- 失败提示必须包含一条可执行建议。

固定角色：

- **修复员 / Restorer**：玩家，不设固定性别或外貌。
- **苔灯 / Mosslight**：基地档案助手，以短句提供教程和结算提示。
- **前任七号 / Predecessor Seven**：只存在于档案中的上一任修复员。

## 2. 核心资源

| ID | 中文 / English | 来源 | 用途 | 显示色 |
|---|---|---|---|---|
| `scrap` | 废料 / Scrap | 常见矿物、合同、回声 | 模块和设施普通升级 | `#D3A45C` |
| `core` | 核心 / Cores | 稀有矿、遗迹、层核心 | 模块突破、关键设施 | `#73D1C8` |
| `data` | 数据 / Data | 扫描、档案、合同 | 科技树和蓝图 | `#8FC7FF` |
| `chronoshard` | 时间碎片 / Chronoshards | 章节软重置 | 永久时间法则与正式版扩展 | `#D59CFF` |

禁止引入原矿、金币、体力、品质粉尘或付费货币。矿物在结算时直接换算为上述资源。

## 3. 基础钻机与操作数值

| 属性 | 初始值 | 说明 |
|---|---:|---|
| 耐久 | 100 | 归零则本次下潜失败 |
| 能量 | 100 | 推进、钻探、冲刺和工具消耗 |
| 热量 | 0～100 | 100 时钻头停机 2 秒 |
| 货舱 | 100 | 满载后仍可移动，但不能采集 |
| 推进加速度 | 520 px/s² | 最大普通速度 150 px/s |
| 重力 | 280 px/s² | 最大下落速度 220 px/s |
| 冲刺 | 260 px/s，0.35 秒 | 冷却 1.2 秒，消耗 18 能量 |
| 钻探距离 | 18 px | 前方 60° 锥形范围 |
| 爆破钉 | 2 发 | 半径 32 px；补给点恢复 1 发 |
| 声呐 | 7 秒冷却 | 显示 112 px 内矿物和危险 2.5 秒 |
| 信标 | 2 枚 | 标记位置及撤离方向 |

同类矿物在 2.5 秒内连续开采形成连击：`1 + min(1.0, streak × 0.1)`。切换矿物家族、受伤或超过窗口会结束连击。

## 4. 装备系统

钻机有 5 个模块槽：钻头、引擎、冷却、工具、框架；另有 1 个遗物槽。每个模块可升 5 级；已购买模块从 1 级开始。由当前等级 `L` 升至 `L+1` 的废料成本为 `round(base_cost × 1.18 ^ (L - 1))`；3 升 4 级时额外消耗 1 核心。表中数值为 1 级效果。

### 4.0 初始档案状态

- 资源：废料 0、核心 0、数据 0、时间碎片 0。
- 已开放地层：废弃工业区。
- 设施：维修工坊 L1；其他设施未建造。
- 默认装备：硬质合金齿 L1、紧凑推进器 L1、铜环散热器 L1、遥控爆破钉 L1、货运框架 L1。
- 遗物槽未解锁、无遗物。
- 科技未解锁；档案只有 `log_01`。
- 首次教学不要求调度台或合同，使用固定教学任务；首次成功后自动给予 50 废料并开放调度台建造及 `contract_first_load`。
- 购买一个未拥有的非默认模块时支付表中“解锁与价格”，获得 L1；后续升级再使用等级公式。
- 软重置保留模块蓝图，但把所有模块等级重置到 L1；默认和已解锁模块均可装备，无需重新支付购买价。

### 4.1 钻头模块

| ID | 中文 / English | 解锁与价格 | 效果 | UI 描述 |
|---|---|---|---|---|
| `drill_carbide` | 硬质合金齿 / Carbide Biter | 默认 | 钻速 100%，每秒热量 12 | 稳定可靠的标准钻头。 / A dependable drill for every layer. |
| `drill_resonance` | 共振叉 / Resonance Fork | 工业层遗迹；180 废料、1 核心 | 同类矿物连击窗口 +1 秒；每层连击使钻速 +2%，最多 20% | 沿矿脉的节奏前进。 / Follow the vein and keep the rhythm. |
| `drill_thermal` | 赤热矛 / Thermal Lance | 化石海遗迹；260 废料、2 核心 | 热量高于 70 时钻速与矿物价值 +25%；低于 30 时钻速 -10% | 让过热成为选择，而非失误。 / Turn overheating into a deliberate risk. |

基础升级成本分别为 55、75、95 废料；每级为钻速 +6%，特殊规则不随等级叠加。

### 4.2 引擎模块

| ID | 中文 / English | 解锁与价格 | 效果 | UI 描述 |
|---|---|---|---|---|
| `engine_compact` | 紧凑推进器 / Compact Thruster | 默认 | 标准推进；能量消耗每秒 6 | 简单、轻巧、不会争辩。 / Light, simple, and unlikely to argue. |
| `engine_vector` | 矢量爆发器 / Vector Burst | 工业合同 3；160 废料、1 核心 | 冲刺距离 +30%，撞碎软岩；冲刺冷却 +0.3 秒 | 用路线预判换取速度。 / Trade foresight for momentum. |
| `engine_gravity` | 重力锚 / Gravity Anchor | 机械城遗迹；260 废料、2 核心 | 松开移动时制动 +60%；长按向下可快速坠落，落地震开脆岩 | 在混乱的重力里保持精确。 / Stay precise when gravity disagrees. |

基础升级成本 50、70、90 废料；每级最大速度 +4%。

### 4.3 冷却模块

| ID | 中文 / English | 解锁与价格 | 效果 | UI 描述 |
|---|---|---|---|---|
| `cooling_copper` | 铜环散热器 / Copper Loop | 默认 | 非钻探时每秒散热 18 | 旧式散热，也是一种可靠。 / Old-fashioned cooling still works. |
| `cooling_phase` | 相位散热片 / Phase Radiator | 工业档案 5；150 废料、1 核心 | 冲刺结束后 1 秒内散热速度 ×2；基础散热 -10% | 把移动节奏变成冷却窗口。 / Cool through deliberate bursts of motion. |
| `cooling_recycler` | 热回收器 / Heat Recycler | 化石海合同 7；240 废料、2 核心 | 热量从 80 降至 60 时恢复 15 能量；每 8 秒最多触发一次 | 回收每一次险些失控。 / Reclaim energy from every near-meltdown. |

基础升级成本 45、65、85 废料；每级散热 +5%。

### 4.4 工具模块

右键或 LT 使用当前工具；声呐和信标为钻机通用功能。

| ID | 中文 / English | 解锁与价格 | 效果 | UI 描述 |
|---|---|---|---|---|
| `tool_blast` | 遥控爆破钉 / Remote Charge | 默认 | 2 发，半径 32 px，伤害环境实体并触发坍塌 | 不是武器，只是岩层偶尔会移动。 / Not a weapon. The rock simply relocates. |
| `tool_shield` | 脉冲护罩 / Pulse Shield | 工业合同 5；180 废料、1 核心 | 消耗 25 能量，抵挡 1 次伤害并推开生物；冷却 8 秒 | 把危险推回安全距离。 / Put danger back where it belongs. |
| `tool_drone` | 测绘蜂 / Survey Drone | 化石海档案 11；220 废料、1 核心 | 放出无人机前进 96 px，标记支路、遗迹和危险；冷却 10 秒 | 先看一眼，再决定值不值得。 / Look first, then decide what the risk is worth. |

基础升级成本 60、75、80 废料；分别提升爆破半径、护罩推力、无人机范围 6%。

### 4.5 框架模块

| ID | 中文 / English | 解锁与价格 | 效果 | UI 描述 |
|---|---|---|---|---|
| `frame_cargo` | 货运框架 / Cargo Frame | 默认 | 货舱 +25，最大速度 -3% | 多带一点，慢一点回家。 / Carry more and come home a little slower. |
| `frame_reinforced` | 加固框架 / Reinforced Frame | 工业合同 2；160 废料、1 核心 | 耐久 +35，受碰撞伤害 -20%，货舱 -10 | 为愿意继续深入的人准备。 / Built for those who keep going. |
| `frame_echo` | 回声框架 / Echo Frame | 机械城档案 16；280 废料、2 核心 | 成功路线稳定度 +0.10；主动矿物价值 -5% | 今天少带一点，让明天持续更多。 / Bring home less today so tomorrow keeps working. |

基础升级成本 55、75、95 废料；每级分别增加 5 货舱、5 耐久、0.015 稳定度。

## 5. 遗物

遗物不能购买，只能在遗迹首次发现；重复发现转化为 40 数据。每次只装备一个。

| ID | 中文 / English | 地层 | 效果 |
|---|---|---|---|
| `relic_ember_pearl` | 余烬珠 / Ember Pearl | 工业 | 热量高于 80 时矿物价值 +20%，受到伤害立即结束当前连击 |
| `relic_shift_compass` | 偏移罗盘 / Shift Compass | 工业 | 声呐额外显示一条推荐安全路线，声呐冷却 +2 秒 |
| `relic_union_badge` | 联结徽章 / Union Badge | 工业 | 每次无伤成功撤离获得 25 废料；失败时额外损失 10% 未入库货物 |
| `relic_fossil_lung` | 化石肺 / Fossil Lung | 化石海 | 靠近孢子或生物组织时能量恢复 +50%，酸液伤害 +20% |
| `relic_chain_seed` | 链生种 / Chain Seed | 化石海 | 连击窗口 +1.5 秒，最大倍率 +0.5；不同矿物基础价值 -10% |
| `relic_gentle_spore` | 温孢 / Gentle Spore | 化石海 | 低于 30 耐久时每 15 秒恢复 5；移动速度 -5% |
| `relic_logic_prism` | 逻辑棱镜 / Logic Prism | 机械城 | 完成合同目标后本次所有数据 +30%；偏离合同会使废料 -10% |
| `relic_echo_compass` | 回声罗盘 / Echo Compass | 机械城 | 路线稳定度 +0.08，回声相同种类资源产量更集中；主动废料 -5% |
| `relic_inverted_heart` | 倒置之心 / Inverted Heart | 机械城 | 重力反转期间矿物价值 +35%；普通重力下冲刺能耗 +20% |

## 6. 基地设施

设施最多 3 级；设施升级不使用指数公式，按表定价。

| ID | 中文 / English | 解锁 | 等级效果与成本 |
|---|---|---|---|
| `facility_workshop` | 维修工坊 / Workshop | 默认 | L1 装备与升级；L2 120 废料：比较面板与预设 2；L3 260 废料+2 核心：预设 3、模块 4→5 |
| `facility_dispatch` | 调度台 / Dispatch | 50 废料 | L1 合同 1 个；L2 140 废料：同时展示 3 个；L3 280 废料+2 核心：每日种子不做，改为一次刷新机会 |
| `facility_refinery` | 精炼炉 / Refinery | 100 废料 | L1 结算废料 +5%；L2 180 废料+1 核心：+10%；L3 360 废料+3 核心：+15%并把满连击溢出转为数据 |
| `facility_archive` | 档案馆 / Archive | 80 废料 | L1 科技树与档案；L2 160 废料：遗迹数据 +15%；L3 320 废料+2 核心：重复遗物转化 +20 数据 |
| `facility_echo` | 回声投影室 / Echo Chamber | 150 废料+20 数据 | L1 1 槽并启用 25%/2 小时离线收益；L2 220 废料+80 数据：2 槽；L3 400 废料+160 数据+2 核心：3 槽、路线比较同时显示全部槽位 |
| `facility_anchor` | 时间锚 / Chrono Anchor | 科技 `tech_anchor_theory` | L1 触发软重置；试玩版无 L2/L3，显示“正式版开放”但不可点击购买 |

## 7. 科技树

科技只消耗数据，必须满足同分支前置。

| 分支 | ID | 中文 / English | 成本 | 效果 |
|---|---|---|---:|---|
| 导航 | `tech_scanner_tuning` | 扫描调谐 / Scanner Tuning | 20 | 声呐范围 +24 px |
| 导航 | `tech_safe_corridor` | 安全走廊 / Safe Corridor | 60 | 地图主路径至少包含 1 个补给点 |
| 导航 | `tech_branch_mapping` | 支路测绘 / Branch Mapping | 140 | 声呐显示最近支路的风险级别 |
| 工业 | `tech_ore_grading` | 矿物分级 / Ore Grading | 20 | 所有矿物价值 +5% |
| 工业 | `tech_cargo_lattice` | 货舱晶格 / Cargo Lattice | 70 | 基础货舱 +20 |
| 工业 | `tech_core_extraction` | 核心提取 / Core Extraction | 160 | 每层首次高风险遗迹固定奖励 1 核心 |
| 回声 | `tech_echo_ledger` | 回声账本 / Echo Ledger | 30 | 解锁投影室和路线登记 |
| 回声 | `tech_dual_projection` | 双重投影 / Dual Projection | 90 | 允许投影室升级至 L2 |
| 回声 | `tech_offline_buffer` | 离线缓冲 / Offline Buffer | 180 | 离线效率从 25% 提高至 40%，上限由 2 小时提高至 4 小时 |
| 时间 | `tech_relic_interface` | 遗物接口 / Relic Interface | 40 | 解锁遗物槽 |
| 时间 | `tech_temporal_pin` | 时间固定 / Temporal Pin | 120 | 软重置时可固定 2 条回声 |
| 时间 | `tech_anchor_theory` | 锚点理论 / Anchor Theory | 240 | 击穿第三层后解锁时间锚和软重置 |

## 8. 矿物

硬度是相对钻探时间倍率；价值为单块结算基准。

| ID | 中文 / English | 地层 | 硬度 | 价值 | 特性 |
|---|---|---|---:|---:|---|
| `ore_ferrite` | 铁屑矿 / Ferrite Scrap | 工业 | 1.0 | 3 废料 | 常见，连续矿脉长 |
| `ore_copper_thread` | 铜丝晶 / Copper Thread | 工业 | 1.2 | 5 废料 | 靠近电缆危险时价值 +20% |
| `ore_lumen` | 灯核晶 / Lumen Crystal | 工业 | 1.8 | 4 废料+2 数据 | 发光，爆破会损失一半数据 |
| `ore_bone_amber` | 骨琥珀 / Bone Amber | 化石海 | 1.3 | 7 废料 | 与生物组织相连，切断后硬度下降 |
| `ore_pulse_coral` | 脉珊瑚 / Pulse Coral | 化石海 | 1.6 | 5 废料+3 数据 | 每 2 秒改变可钻方向 |
| `ore_symgel` | 共生胶 / Symbiotic Gel | 化石海 | 0.8 | 4 废料 | 采集后恢复 4 能量，8 秒内最多 3 次 |
| `ore_polar_alloy` | 极性合金 / Polar Alloy | 机械城 | 1.5 | 9 废料 | 重力反转时硬度减半 |
| `ore_logic_prism` | 逻辑棱晶 / Logic Prism | 机械城 | 2.0 | 6 废料+5 数据 | 必须从发光面钻入才获完整价值 |
| `ore_chronodust` | 时尘结晶 / Chronodust | 机械城 | 2.4 | 12 废料+8 数据 | 每次声呐后显形 4 秒；每次下潜最多 3 块 |

核心不作为普通矿物生成：每个地层首次遗迹、层核心和部分合同奖励核心。

## 9. 环境危险

| ID | 中文 / English | 地层 | 行为 | 反制 | 伤害 |
|---|---|---|---|---|---:|
| `hazard_steam` | 蒸汽喷口 / Steam Vent | 工业 | 1.5 秒预警后喷射 1 秒 | 声呐显示节奏；等待或冲刺穿过 | 15 |
| `hazard_cable` | 活电缆 / Live Cable | 工业 | 接触并持续放电 | 爆破切断电源节点 | 8/秒 |
| `hazard_shale` | 坍塌页岩 / Collapse Shale | 工业 | 支撑被移除后延迟坠落 | 信标提示危险区；从侧面开采 | 20 |
| `hazard_spore` | 孢囊 / Spore Sac | 化石海 | 受震动后释放减速云 | 慢速钻探或远程爆破 | 5+减速 |
| `hazard_vine` | 绞藤 / Constrict Vine | 化石海 | 接触后拉向组织核心 | 爆破核心或连续反向推进 | 6/秒 |
| `hazard_acid` | 酸液袋 / Acid Pocket | 化石海 | 破裂后液滴持续 6 秒 | 从上方引流或用护罩推开 | 10/次 |
| `hazard_gravity` | 重力换向器 / Gravity Inverter | 机械城 | 周期反转局部重力 | 声呐显示倒计时；重力锚减弱影响 | 间接 |
| `hazard_phase_saw` | 相位锯 / Phase Saw | 机械城 | 沿固定轨道间歇移动 | 看节奏或爆破轨道节点暂停 5 秒 | 25 |
| `hazard_sentinel` | 哨戒节点 / Sentinel Node | 机械城 | 锁定后发射推力脉冲 | 躲到岩层后或爆破电源 | 12+击退 |

### 9.1 危险运行参数

| ID | 固定参数 |
|---|---|
| `hazard_steam` | 周期 4 秒；预警 1.5 秒；喷射 1 秒；射程 64 px；同一喷射只伤害一次 |
| `hazard_cable` | 感电范围 20 px；每 0.5 秒结算 4 伤害；电源节点需钻探 1.5 秒或一次爆破 |
| `hazard_shale` | 支撑消失 0.6 秒后坠落；最大速度 180 px/s；落地后变为普通脆岩 |
| `hazard_spore` | 受钻探震动 0.8 秒后释放；云半径 40 px、持续 6 秒、移动与钻速 -40% |
| `hazard_vine` | 感知 64 px；拉力 70 px/s；核心需连续钻探 1.5 秒或一次爆破 |
| `hazard_acid` | 破裂后生成 6 滴，间隔 0.2 秒；液滴存在 6 秒、每滴同一目标只伤害一次 |
| `hazard_gravity` | 场半径 80 px；每 6 秒反转、提前 1 秒闪烁；离场立即恢复全局重力 |
| `hazard_phase_saw` | 轨道长度 64～112 px；移动 80 px/s；端点停 0.5 秒；轨道节点被爆破后停 5 秒 |
| `hazard_sentinel` | 感知 128 px；锁定 1.2 秒；脉冲速度 160 px/s；发射冷却 3 秒；电源关闭后永久停机 |

## 10. 环境生物

生物使用“平静、警觉、惊扰、撤退”状态，不显示生命条，不掉落装备。

| ID | 中文 / English | 地层 | 行为 | 处理方式 |
|---|---|---|---|
| `creature_scrap_mite` | 拾屑虫 / Scrap Mite | 工业 | 偷走附近未采集矿块并逃向巢穴 | 爆破震退、护罩推开；跟踪可发现小型矿室 |
| `creature_tunnel_manta` | 穴鳐 / Tunnel Manta | 化石海 | 沿开放空间巡游，被高速钻探惊扰后冲撞 | 降速、躲避或用测绘蜂引走 |
| `creature_archive_warden` | 档案守望者 / Archive Warden | 机械城 | 守卫遗迹入口，模仿玩家最近一次冲刺方向 | 用重力机关、爆破脉冲或假信标引开 |

运行参数：拾屑虫移动 55 px/s，每 2 秒偷取附近 1 块未采矿并最多携带 3 块，惊扰后逃离 6 秒；穴鳐巡游 45 px/s，警觉 0.8 秒后以 150 px/s 冲刺 0.7 秒，碰撞后撤退 4 秒；守望者巡逻 35 px/s、追踪 60 px/s，看到玩家 1 秒后复制最近冲刺方向，受到爆破或假信标影响后转移目标 5 秒。

## 11. 地层定义

M3 当前正式地图算法版本为 `generator_version = 2`。该版本只改变灰盒房间组成与拓扑：工业层普通房 4～6、风险房 1～2；化石海普通房 5～7、风险房 2；机械城普通房 6～8、风险房 2～3，并固定包含 2 个遗迹房。内容 ID 与数值仍为 `content_version = 1`。

### 11.1 废弃工业区 / Abandoned Works

- 目标时长：15～20 分钟。
- 色板重点：铁锈、铜、煤黑、暖黄灯。
- 地层规则：蒸汽周期与结构坍塌。
- 房间组成：入口 1、普通矿区 4～6、风险房 1～2、补给 1、遗迹 1、出口 1。
- 教学固定种子：`170101`。
- 层核心事件：恢复主锅炉。进入房间启动 45 秒计时，三个阀门各需保持交互 0.8 秒；每完成一个阀门降低蒸汽频率。超时产生一次 30 伤害的全房蒸汽脉冲，5 秒后阀门重置并允许重试，不结束本次下潜。完成后永久关闭房间危险。
- 完成奖励：2 核心、60 数据、解锁化石海。

### 11.2 生物化石海 / Fossil Sea

- 目标时长：20～25 分钟。
- 色板重点：骨白、苔绿、珊瑚橙、深青。
- 地层规则：部分通道每 30 秒缓慢生长一轮；只重建标记为可生长的软组织。
- 房间组成：入口 1、普通区 5～7、风险房 2、补给 1、遗迹 1～2、出口 1。
- 首次种子：`240203`。
- 层核心事件：在不破坏中央孢巢的情况下切断 4 条寄生管线。每条管线需连续钻探 3 秒；中央孢巢受到爆破时造成 25 伤害并让最近切断的管线再生。事件无总计时，全部切断后中央孢巢恢复并永久停止生长。
- 完成奖励：3 核心、90 数据、解锁机械城。

### 11.3 倒置机械城 / Inverted Machine City

- 目标时长：25～35 分钟。
- 色板重点：深蓝、银灰、紫、电青。
- 地层规则：局部重力按可见倒计时切换；逻辑门改变通道。
- 房间组成：入口 1、普通区 6～8、风险房 2～3、补给 1～2、遗迹 2、时间核心 1。
- 首次种子：`310307`。
- 时间核心事件：90 秒内调整重力，将 3 枚时间钥匙依次送入同色插槽；一次只能牵引一枚钥匙，局部重力每 15 秒反转。守望者只造成空间压力。超时令钥匙复位并造成 20 伤害，5 秒后可重试；已插入钥匙不保留。完成后计时停止并开放时间锚。
- 完成奖励：4 核心、160 数据并开放时间锚；3 时间碎片只在随后确认软重置时发放一次。

### 11.4 房间模块目录

连接记号为 `N/E/S/W`；连接口位于对应边中央，宽 3 格。尺寸单位为 16×16 瓦片。除核心房外，生成器可镜像但不可旋转带重力机关的房间。

| ID | 地层 | 尺寸 | 连接 | 标签与固定内容 |
|---|---|---:|---|---|
| `room_ind_entry` | 工业 | 20×12 | E,S | 安全入口、4 铁屑矿、教程提示 |
| `room_ind_vein` | 工业 | 24×16 | W,E | 长铁屑/铜丝矿脉，无强制危险 |
| `room_ind_shaft` | 工业 | 16×24 | N,S,E | 竖井、1 坍塌页岩区 |
| `room_ind_steam_cross` | 工业 | 24×20 | N,E,S,W | 2 蒸汽喷口、中央高价值矿 |
| `room_ind_cable_vault` | 工业 | 20×16 | W,E | 活电缆与电源节点、灯核晶 |
| `room_ind_mite_nest` | 工业 | 20×16 | W,E,S | 1 拾屑虫、隐藏小矿室 |
| `room_ind_supply` | 工业 | 16×12 | W,E | 恢复 30 耐久、1 爆破钉、1 信标 |
| `room_ind_relic` | 工业 | 24×20 | W,E | 工业遗物候选、风险预算 3 |
| `room_ind_core` | 工业 | 32×20 | W | 三压力阀核心事件 |
| `room_bio_entry` | 化石海 | 20×14 | E,S | 安全入口、骨琥珀教学 |
| `room_bio_garden` | 化石海 | 24×18 | W,E | 骨琥珀枝条、可生长组织 |
| `room_bio_pulse` | 化石海 | 22×18 | W,E,S | 脉珊瑚方向周期 |
| `room_bio_spore` | 化石海 | 20×20 | N,E,S | 3 孢囊、共生胶安全口袋 |
| `room_bio_vine_well` | 化石海 | 18×24 | N,S | 绞藤与下方酸液袋 |
| `room_bio_manta` | 化石海 | 28×16 | W,E | 穴鳐巡游空间、上下绕行路线 |
| `room_bio_supply` | 化石海 | 16×12 | W,E | 恢复 25 耐久、35 能量、1 工具补给 |
| `room_bio_relic` | 化石海 | 26×20 | W,E | 化石海遗物候选、不可爆破中央台 |
| `room_bio_core` | 化石海 | 32×24 | W | 孢巢与四寄生管线事件 |
| `room_mech_entry` | 机械城 | 20×14 | E,S | 安全入口、重力倒计时演示 |
| `room_mech_polarity` | 机械城 | 24×18 | W,E | 极性合金、局部重力反转 |
| `room_mech_logic` | 机械城 | 24×20 | W,E,S | 两状态逻辑门、逻辑棱晶 |
| `room_mech_saw` | 机械城 | 22×18 | W,E | 相位锯轨道与停机节点 |
| `room_mech_sentinel` | 机械城 | 26×18 | W,E,S | 哨戒节点、岩层掩体 |
| `room_mech_warden` | 机械城 | 28×22 | W,E | 守望者、假信标解法、遗迹入口 |
| `room_mech_supply` | 机械城 | 16×14 | W,E | 恢复 30 耐久、50 能量、2 工具补给 |
| `room_mech_relic` | 机械城 | 26×22 | W,E | 机械遗物候选、时尘上限检查 |
| `room_mech_core` | 机械城 | 36×26 | W | 三钥匙与三阶段重力事件 |

每层还需一个不参与随机生成的保底地图，使用该层入口、2 个普通房、补给房、遗迹房和核心/出口房按主路径顺序拼接。

## 12. 合同

合同失败不扣除资源，只失去合同奖励。一次下潜只能选择一个。

| ID | 中文 / English | 解锁 | 条件 | 奖励 |
|---|---|---|---|---|
| `contract_first_load` | 第一批货 / First Shipment | 默认 | 带回 45 废料价值 | 35 废料、10 数据 |
| `contract_clean_hull` | 完整外壳 / Clean Hull | 工业层 | 受伤不超过 15 | 50 废料、15 数据；解锁加固框架 |
| `contract_fast_line` | 快线 / Express Line | 工业层 | 180 秒内成功撤离 | 60 废料、1 核心；解锁矢量爆发器 |
| `contract_lumen_care` | 灯核保护 / Handle With Light | 工业档案 4 | 带回 6 块未被爆破损伤的灯核晶 | 70 废料、25 数据 |
| `contract_pressure_test` | 压力测试 / Pressure Test | 工业核心 | 全程过热不超过 1 次 | 80 废料、1 核心；解锁脉冲护罩 |
| `contract_living_sample` | 活体样本 / Living Sample | 化石海 | 带回三类生物矿物各 4 块 | 100 废料、35 数据 |
| `contract_cool_return` | 冷却回航 / Cool Return | 化石海 | 结束时热量低于 20、能量高于 50 | 120 废料、2 核心；解锁热回收器 |
| `contract_no_burst` | 轻声经过 / Quiet Passage | 化石海档案 10 | 不使用爆破钉并成功撤离 | 130 废料、50 数据 |
| `contract_logic_route` | 逻辑路线 / Logical Route | 机械城 | 依序采集极性合金、逻辑棱晶、时尘 | 160 废料、65 数据 |
| `contract_echo_record` | 值得重复 / Worth Repeating | 投影室 L2 | 登记稳定度 ≥0.90 且每分钟价值超过 140 的路线 | 200 废料、2 核心、80 数据 |

## 13. 时间回声与软重置内容

路线稳定度：

```text
stability = clamp(
  1.0
  - damage_taken / max_health * 0.25
  - overheat_count * 0.04
  - emergency_collision_count * 0.02,
  0.60,
  1.00
)
```

回声在线效率为记录账本的 `60% × stability × upgrades`。科技解锁前离线效率 25%、上限 2 小时；`tech_offline_buffer` 后为 40%、上限 4 小时。

时间法则：

| ID | 中文 / English | 永久效果 | 代价 |
|---|---|---|---|
| `law_redline` | 赤热生产 / Redline Industry | 热量 ≥80 时主动矿物价值 +20% | 基础散热 -15% |
| `law_stable_echo` | 稳定回响 / Stable Reverberation | 所有回声稳定度下限 0.75，产量 +10% | 主动合同废料奖励 -10% |
| `law_hidden_strata` | 隐秘地层 / Hidden Strata | 每图增加 1 个遗迹候选支路，遗迹数据 +25% | 主路径普通矿物密度 -12% |

首次软重置奖励 3 时间碎片，选择并激活一个时间法则消耗 3 时间碎片。试玩版只能激活一个法则，不提供重复刷取或法则升级。

软重置保留：未消费的数据余额、科技、模块蓝图、遗物发现、设施等级、档案、全局设置、时间碎片余额、基地外观、所选法则和最多 2 条固定回声。重置：废料、核心、所有模块等级回到 L1、合同状态、地图种子、当前运行状态和未固定回声。重置后只开放工业层，后续层按原条件重新击穿；设施无需重建。

## 14. 经济节奏预算

以普通玩家、无失败、未计算一次性合同奖励为基准：

| 游戏时间 | 主动废料/5 分钟 | 回声废料/5 分钟 | 数据累计目标 | 核心累计目标 | 预期里程碑 |
|---|---:|---:|---:|---:|---|
| 0～15 分钟 | 55～75 | 0 | 35～55 | 0～1 | 两次普通升级、档案馆 |
| 15～30 分钟 | 85～115 | 25～45 | 90～130 | 2～3 | 首个规则模块、首条回声 |
| 30～50 分钟 | 120～160 | 55～85 | 190～260 | 5～7 | 化石海、第二回声槽 |
| 50～70 分钟 | 165～220 | 90～130 | 330～430 | 8～11 | 机械城、遗物构筑成形 |
| 70～90 分钟 | 220～300 | 130～190 | 500～650 | 12～16 | 时间核心与软重置 |

规则：

- 任意连续 10 分钟必须至少出现一个可购买的有效升级或新内容。
- 回声贡献应覆盖下一阶段升级成本的 20%～40%，不能成为最优的唯一来源。
- 失败后的平均恢复时间不超过 6 分钟。
- 单一构筑在统一模拟中的总收益不得超过第二名 20%；超过则调整协同或代价。
- 试玩版显示数值不得超过 `1e9`。

## 15. 教程与关键提示最终文案

| 键 | 中文 | English |
|---|---|---|
| `tutorial.move` | 推进钻机，找到岩层的薄弱处。 | Thrust toward a thinner section of rock. |
| `tutorial.aim_drill` | 瞄准并持续钻探。热量越高，停机风险越大。 | Aim and hold to drill. More heat means a greater shutdown risk. |
| `tutorial.cargo` | 矿物会占用货舱。满载后请撤离或放弃低价值路线。 | Minerals fill your hold. Extract or leave low-value veins behind. |
| `tutorial.heat` | 热量接近上限。停止钻探，移动时寻找冷却窗口。 | Heat is near its limit. Stop drilling and make room to cool. |
| `tutorial.blast` | 发射爆破钉，再次按下工具键引爆。 | Fire a remote charge, then press the tool action again to detonate it. |
| `tutorial.sonar` | 声呐会短暂标记矿物、危险与支路。 | Sonar briefly marks minerals, hazards, and branches. |
| `tutorial.extract` | 长按撤离。成功带回全部货物，损毁只保留一半。 | Hold to extract. Success keeps everything; destruction keeps only half. |
| `tutorial.upgrade` | 把本次收获变成下一次的选择。 | Turn this haul into a new choice for the next dive. |
| `tutorial.echo` | 这条成功路线可以成为时间回声，替你持续生产。 | This successful route can become an Echo and keep producing for you. |
| `failure.destroyed` | 钻机损毁。未入库货物损失一半；试着更早撤离或换用加固框架。 | Drill destroyed. Half the unbanked cargo was lost. Extract earlier or try a reinforced frame. |
| `failure.abandoned` | 本次下潜已放弃，未结算货物没有带回基地。 | Dive abandoned. Unsettled cargo was left behind. |

## 16. 档案文本

| ID | 中文标题 / English | 解锁 | 最终文本（中文 / English） |
|---|---|---|---|
| `log_01` | 第一盏灯 / The First Lamp | 开局 | 档案站没有欢迎词，只有一盏仍愿意亮起的灯。苔灯说，这已经足够开始。 / The Archive had no welcome message, only one lamp still willing to glow. Mosslight said that was enough to begin. |
| `log_02` | 前任的扳手 / A Predecessor's Wrench | 首次升级 | 扳手柄上刻着七道划痕。前任七号也从松动的螺栓和很小的希望开始。 / Seven marks were cut into the handle. Predecessor Seven also began with loose bolts and a very small hope. |
| `log_03` | 锅炉公约 / The Boiler Accord | 工业普通遗迹 | 工人们约定，最后离开的人要关掉蒸汽。后来谁也没能确认自己是不是最后一个。 / The workers agreed that the last person out would close the steam. In the end, no one could be certain they were last. |
| `log_04` | 灯核 / Lumen Cores | 发现灯核晶 | 他们把夜班的灯做成可更换的晶体，也把每一班人的名字刻在灯座下面。 / They made the night-shift lamps replaceable, then carved every crew's names beneath the sockets. |
| `log_05` | 有限压力 / Finite Pressure | 工业风险房 | 锅炉记录反复写着同一句话：压力有上限，产量目标没有。机器先理解了其中的问题。 / Boiler records repeat one line: pressure had a limit; the quota did not. The machines understood the problem first. |
| `log_06` | 交接班 / Shift Change | 完成工业核心 | 主锅炉重新点燃时，旧广播播放了交接铃。数百年后，终于有人来接下一班。 / When the main boiler reignited, the old shift bell played. Centuries later, someone had finally arrived for the next watch. |
| `log_07` | 会呼吸的海 / A Sea That Breathes | 进入化石海 | 岩层在缓慢收缩。这里的文明没有征服地下，他们让城市学会与地下共同呼吸。 / The strata contract slowly. This civilization did not conquer the deep; it taught its city to breathe with it. |
| `log_08` | 骨琥珀园 / The Bone-Amber Garden | 发现骨琥珀 | 每一块琥珀原本都是支撑隧道的活体枝条。被取走前，园丁会种下两枝新的。 / Every amber piece was once a living brace. Gardeners planted two new branches before taking one away. |
| `log_09` | 温孢 / Gentle Spores | 发现温孢遗物 | 医疗孢子不知道战争已经结束。它们仍在寻找受伤的人，并对每一台钻机抱有希望。 / The medical spores never learned the war was over. They still search for the injured and remain optimistic about every drill. |
| `log_10` | 轻声经过 / Passing Quietly | 无爆破完成合同 | 化石海会记住剧烈的声音，却允许耐心的人通过。安静在这里不是谨慎，而是礼貌。 / The Fossil Sea remembers violent noise but permits patient travelers. Quiet here is not caution; it is courtesy. |
| `log_11` | 测绘蜂群 / Survey Swarm | 解锁测绘蜂 | 蜂群最初用来寻找新生的通道。它们从不选择路线，只把选择留给跟在后面的人。 / The swarm once searched for newborn passages. It never chose a route, leaving that responsibility to whoever followed. |
| `log_12` | 不破坏的修复 / Repair Without Ruin | 完成化石核心 | 切断寄生管线后，中央孢巢重新发光。修复并不总意味着把旧东西换掉。 / When the parasitic lines were cut, the central nest glowed again. Repair does not always mean replacing what was there. |
| `log_13` | 倒置城市 / The Inverted City | 进入机械城 | 城市每隔一段时间改变上下，因为建造者认为方向不该成为建筑的限制。 / The city changed up and down at intervals because its builders refused to let direction limit architecture. |
| `log_14` | 逻辑门 / Logic Gates | 首次开启逻辑门 | 门没有锁。它只是坚持要让进入者证明，自己知道为什么要进去。 / The door was not locked. It merely insisted that entrants know why they wished to pass. |
| `log_15` | 守望者 / The Warden | 遇到守望者 | 守望者不攻击档案，它只阻止匆忙的人靠近。几百年来，它把沉默误认为了耐心。 / The Warden does not attack the Archive; it keeps haste away. For centuries, it mistook silence for patience. |
| `log_16` | 回声罗盘 / Echo Compass | 获得回声罗盘 | 罗盘不指向北方。它指向一条已经走过、却仍值得走得更好的路。 / The compass does not point north. It points toward a route already traveled, but still worth improving. |
| `log_17` | 三枚钥匙 / Three Keys | 时间核心阶段二 | 三枚钥匙分别代表生产、记忆和选择。城市认为缺少其中任何一项，延续都只是重复。 / The three keys stand for production, memory, and choice. The city believed continuity without any one of them was merely repetition. |
| `log_18` | 下一条时间线 / The Next Timeline | 完成软重置 | 时间重组没有抹去基地，只重新排列了尚未完成的工作。苔灯把新的第一盏灯交给了你。 / The reformation did not erase the Archive; it rearranged the work left unfinished. Mosslight handed you the next first lamp. |

## 17. 美术内容清单

- 钻机：1 个 32×32 主体，待机 4 帧、推进 4 帧、钻探 6 帧、过热 4 帧、受损 2 状态、损毁 8 帧。
- 模块叠加：15 个模块各 1 个静态层；矢量引擎、热矛、护罩、无人机额外动画。
- 地层：每层至少 48 个 16×16 瓦片，包含边缘、转角、背景、支撑、可破坏和不可破坏版本。
- 矿物：9 种，各 4 帧或 2 帧闪烁。
- 危险：9 种，至少待机、预警、激活三个状态。
- 生物：3 种，每种平静 4 帧、移动 4 帧、惊扰 4 帧、撤退 4 帧。
- 基地：6 座设施，每座关闭、L1、L2、L3 状态；时间锚只需关闭与 L1。
- UI：资源 4、模块 15、遗物 9、科技 12、合同 10、状态与输入图标不少于 24。

最终 RGB 色板、命名、导入与生成规则由技术规格固定；任何新增资产必须先在本清单中登记。
