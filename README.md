# Minecraft Explorer’s Handbook Game · 方境

> 非官方 Minecraft 同人项目，与 Mojang Studios、Microsoft 或 Minecraft 官方没有隶属关系。

关键词：Minecraft、Explorer’s Handbook、Minecraft Explorer’s Handbook、方境、3D、Godot、Godot 4、第一人称、探索、生存、村庄、交易、地图、中文游戏。

基于用户提供的《Minecraft Explorer’s Handbook》内容规划的中文第一人称 3D 探索游戏。**当前 v0.2 包含“林地营地”与第二阶段“第一次平原远行”：补给、床、烹饪、村庄、交易、地图和返回。温带区域的其他场景及后续大章尚未实现。**

## 启动

双击上一层目录的 **方境.app**，或使用 **开始探索.command**。无需另外安装运行库。

Godot 4.7.2 stable 已安装在上一层 `.tools/godot-4.7.2/`，不修改现有系统应用。`方境.app` 是本地启动器，请与 `explorer` 和 `.tools` 放在同一目录。双击 **打开游戏工程.command** 可打开编辑器。项目入口是 `project.godot`。

## 第一次玩

1. 点击“开始我的第一天”。鼠标控制视线，W/A/S/D 控制行走，空格跳跃。
2. 走近橡树，对准树干，按住鼠标左键收集原木。
3. Tab 打开制作：先把原木变成木板，再做工作台。
4. 在营地“工作台位置”旁按 E 放置。附近按 Tab 做木棍与木镐。
5. 按 2 装备木镐。到石丘按住左键开采圆石与煤。
6. 回小屋地基附近，按住右键按蓝图建造。每块消耗一份圆石，共 46 块。
7. 在工作台制作木门，用煤和木棍制作火把。小屋附近按 E 依次安装。安装火把后，E 会用于正常开关门。
8. 对准门按 E 开门，走进小屋，再关门。按 N 开始第一夜，留在屋内 30 秒等到黎明。

不熟悉操作也没关系：左侧只显示当前目标。开始时不会自动天黑。Esc 暂停，可“回到营地”或保存退出。J 查看整本书的章节路线。场景外缘和未开放水域会将你送回营地，不扣物资。

## 已完成第一夜，接着这样玩

你的原房屋、工具和资源会继续保留。新目标显示在左侧：

1. 小屋门外左侧有“远行补给箱”，对准按 E，领取一次性教学物资。
2. 工作台旁按 Tab，用 3 羊毛 + 3 木板制作白色床。制作列表现在可滚动，并显示已有数量。
3. 走进原来的小屋，按 E 放床；对准床再按 E，可设定安全重生点。
4. 对准熔炉按 E，选择烹饪牛肉。消耗燃料后等待 6 秒，成品自动进入背包。没有熔炉时先用 8 圆石制作并在工作台旁摆放。
5. 沿石丘附近的小路向西北走，跟随“村庄 ↖”路牌。村里有农田、水井、旅人小屋、农夫和制图师。
6. 对准成熟麦穗按 E 收获；与农夫交易，6 小麦换 1 绿宝石；与制图师交易，1 绿宝石换定位地图。
7. M 打开地图，F 查看并食用补给。带着地图回到营地小屋附近，完成第一次远行。

村庄房屋可以进入，工作台可以制作，旅人小屋的床也能设定重生点。当前饥饿值不造成死亡，但太饿时不能快跑。

## 现有内容

- 96×96 米林地和平原村庄、河流景观、石丘、三间村舍、水井、摊位、农田与村民。
- 书图参考重建的木镐、石斧、火把、白床、箱子、工作台、熔炉、木门、制图台与圆石平顶小屋。
- 20 种物品、10 个制作配方、3 个村民交易、烹饪/烧炭、46 块小屋蓝图、工作台范围限制、4 个工具槽。
- 新手目标、中文制作与背包、章节手记、安全首夜、关键动作和定时存档。
- 采集/建造/制作的简短音效。

## 当前范围

这是逐章开发版本。建造仍采用辅助蓝图，尚未实现自由地形挖掘、任意搭建、怪物战斗、耐久、船、完整种植和地图合成/缩放。熔炉支持牛肉烹饪与原木烧炭；未加入矿物冶炼。床支持休息点，暂不包含完整昼夜作息。石斧加快采木，木镐采石；第一夜仍为安全教学。

后续章节内容、系统依赖及书图/文字依据见 `docs/PROJECT_PLAN.md`。图片提供外观证据，正文提供功能与配方，教学改编单独记录。

第二阶段逐页依据与教学改编见 `docs/VILLAGE_PLAN.md`。物资礼包、村民交易价格、农田 90 秒再成熟等属于教学设定。

## 存档

存档由 Godot 放在 `user://expedition_v1.json`（macOS 通常在 `~/Library/Application Support/Godot/app_userdata/方境 · 探索者手记/`）。文件名保持不变，内部格式升级为 version 2，兼容旧存档并生成 `.pre-v2` 备份。除原进度外，还保存食物状态、地图、作物、床边位置与熔炼任务。夜晚倒计时不持久化，重进后可再按 N 开始。

## 资产与开发

- `data/`：章节、物品、配方与交易 JSON。
- `scripts/progress.gd`：配方/库存/存档与任务状态。
- `scripts/world.gd`：分区地形、资源点、蓝图和营地。
- `scripts/player.gd`：角色、相机、工具与射线。
- `scripts/hud.gd`：中文 HUD 与交互面板。
- `scripts/art.gd`：程序道具、面材质和场景标签。
- `scripts/village.gd`：村庄建筑、职业村民和农田。
- `scripts/journey.gd`：第二阶段任务、熔炉/食物/交易 UI 与探索记录。
- `scripts/exploration_map.gd`：按世界坐标绘制已探索地图。
- `tools/build_assets.py`：确定性像素纹理源。
- `tools/build_models.py`：Blender 模型重建源；输出 GLB 和可编辑 `.blend`。
- `source_models/`：可编辑 Blender 文件，避免 Godot 再次导入 `.blend`。
- `assets/reference/`：用户 EPUB 的本地参考图，不导入游戏、不加入版本控制。
- `assets/fonts/`：Noto Sans SC，许可证 OFL。

重建本地启动器：`python3 tools/package_local.py`。

重建模型：`/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_models.py`

验证：从项目上一层运行 Godot `--headless --path explorer --script tests/test_progress.gd`；集成流程用 `--headless --path explorer --script tests/test_playthrough.gd -- --integration`。测试存档使用 `/tmp/explorer-test-save.json`，不影响玩家进度。

第二阶段集成测试：`--headless --path explorer --script tests/test_village.gd -- --integration --fixture=res://tests/fixtures/camp_v1.json`。去掉 `--headless` 可实际渲染并保存截图；测试只写 `/tmp/explorer-village-save.json`。
