# M2 无指导试玩与封板记录

试玩说明：请自行探索。目标是移动、瞄准、钻探，并在需要时使用工具、声呐、信标和长按撤离。请勿在开始前获得口头操作说明。

## 封板签字

> 本记录的汇总结论由项目验收方确认；为保护试玩者隐私，不记录姓名或原始评分明细。

```text
M2_ACCEPTANCE_STATUS=ACCEPTED
M2_ACCEPTED_BUILD=b0dd0c3dc1f6fb9bd49d1ef05acce0f4143da860
M2_ACCEPTANCE_DATE=2026-08-12
M2_UNMODERATED_SESSIONS=5
M2_UNIQUE_PLAYERS=3
M2_INPUT_COVERAGE=keyboard_mouse,gamepad
M2_UNDERSTOOD_WITHIN_3_MINUTES=5/5
M2_AVERAGE_DRILL_FEEL_AT_LEAST=4.0
M2_SECOND_DIVE_SESSIONS_AT_LEAST=3
M2_BLOCKING_DEFECTS=0
M2_DUAL_INPUT_10_MINUTE_RUNS=PASS
M2_ACCEPTED_BY=project_acceptance
```

## 通过结论

M2 的键鼠与手柄各完成连续 10 分钟游玩；无卡死、穿墙或输入锁死。无指导试玩覆盖至少 3 名真人与 5 场，全部在 3 分钟内理解移动、钻探与撤离；钻探手感平均不低于 4/5，至少 3 场主动开始第二次下潜，阻断问题为 0。

此记录与 `tools/m2_acceptance_gate.ps1` 共同构成 M2→M3 的硬闸口。任一指标、被验收提交或自动验证发生变化，必须重新进行人工验收并更新此记录。
