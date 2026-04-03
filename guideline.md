# Project Guidelines

这个文件用于记录本项目开发时必须遵守的协作规范。

## 1. 真机运行是默认流程

- 每次完成代码修改后，都必须先执行 `build`。
- `build` 成功后，必须将 App 安装并运行到当前已连接的测试手机上。
- 默认使用已连接的真机进行验证，不使用模拟器，除非我明确说明要用模拟器。
- 如果真机无法运行，需要明确说明阻塞原因，例如设备未连接、签名失败、安装失败或启动失败。

## 2. 当前执行要求

- 当前项目的默认验证方式，是在已连接的测试手机上完成 `build -> install -> launch`。
- 每次改完代码后的汇报中，需要说明是否已经在真机上成功运行。

## 3. 后续维护

- 新的开发规则可以继续追加到这个文件中。
- 后续所有新会话开始时，都应优先遵守这里定义的规则。

## 4. 菜品缓存与标签系统工作流

- App 端只负责从后端读取并显示菜品、图片和标签，不允许在 App 内触发菜品生成、图片生成或标签生成。
- 普通用户请求 `POST /v1/taste/deck` 时，后端只返回数据库里已经存在的缓存菜品；没有库存时就返回空结果，不做自动补货。
- 菜品生成、图片生成、标签生成都只能通过手动管理脚本完成，不能重新改回“App 触发生成”的模式。

### 4.1 当前标签系统的核心约定

- 菜品正式标签统一存英文 canonical keys，不存中文自由文本。
- 标签按这些维度分组：
  - `flavor`
  - `ingredient`
  - `texture`
  - `cooking_method`
  - `cuisine`
  - `course`
  - `allergen`
- 菜品层不存 AI 主观分数；一条菜只存“有哪些标签”，用户画像分数由用户行为统计得到。
- 中文只用于展示层，App 负责把英文 canonical tags 映射成中文标签。
- 复合味型必须拆成原子标签，例如：
  - `麻辣 -> numbing + spicy`
  - `酸辣 -> sour + spicy`
  - `咸鲜 -> salty + umami`

### 4.2 标签生成的原则

- 菜名来源必须优先是人工审核过的名单，不能默认让后端自由生成新菜名。
- 生成流程是两条线并行但都发生在“入库前”：
  - 一条线根据菜名生成图片
  - 一条线根据菜名和菜系生成结构化标签
- 标签生成使用 Gemini 文本模型，但必须受 canonical dictionary 和 normalization rules 约束，不能自由落库。
- Gemini 返回的原始结果不能直接进入正式标签字段，必须先经过系统端标准化。
- 不在字典里的新词不能直接进入正式 tags，先进入 `candidate_tags`。

### 4.3 数据库存储约定

- `dishes.tags_json`：正式 canonical tags，按维度分组。
- `dishes.raw_tagging_output`：Gemini 原始标签输出。
- `dishes.candidate_tags_json`：不在正式字典里的候选标签。
- `dishes.tagging_trace_json`：alias 映射、复合词拆分、补全等处理痕迹。
- `dishes.tagging_version`：本次标签规则和 prompt 的版本。
- 旧字段 `signals` 和 `category_tags` 仅保留兼容用途，不应再作为新逻辑的主数据来源。

### 4.4 相关文件

- 标签字典、canonical tags、prompt、normalization 规则：`backend/app/tagging.py`
- 后端标签生成与 deck 返回：`backend/app/main.py`
- 数据库字段定义：`backend/app/models.py`
- 数据库迁移：`backend/alembic/versions/0002_add_tag_storage.py`
- 手动补菜/补标签/补图脚本：`backend/scripts/dish_cache_admin.py`
- App 端标签模型和展示：`readytoorder/TasteModels.swift`、`readytoorder/TasteBackendClient.swift`、`readytoorder/TasteLearning/`

### 4.5 新增或重建菜品时的标准流程

- 第一步：先准备人工审核过的菜名清单，优先使用 `菜系|菜名` 格式。
- 第二步：把名单写入 `backend/data/approved_dishes.txt` 或新的 UTF-8 文本文件。
- 第三步：通过手动脚本导入，不要通过 App。

本地示例：

```bash
cd /Users/young/Coding/development/readytoorder/backend
PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

如果只想补标签、不重跑图片：

```bash
cd /Users/young/Coding/development/readytoorder/backend
PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt --skip-images
```

如果要先清空再重建：

```bash
cd /Users/young/Coding/development/readytoorder/backend
PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py clear --yes-i-understand
PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

Railway 生产环境常用方式：

```bash
cd /Users/young/Coding/development/readytoorder/backend
export DATABASE_URL="$(npx -y @railway/cli variable list --service Postgres-RkMM -e production -k | sed -n 's/^DATABASE_PUBLIC_URL=//p')"
export GEMINI_API_KEY="$(npx -y @railway/cli variable list --service readytoorder -e production -k | sed -n 's/^GEMINI_API_KEY=//p')"
export GEMINI_MODEL="$(npx -y @railway/cli variable list --service readytoorder -e production -k | sed -n 's/^GEMINI_MODEL=//p')"
export GEMINI_IMAGE_MODEL="$(npx -y @railway/cli variable list --service readytoorder -e production -k | sed -n 's/^GEMINI_IMAGE_MODEL=//p')"
export APP_ENV=production
PYTHONUNBUFFERED=1 PYTHONPATH=. .venv/bin/python scripts/dish_cache_admin.py seed-names --input data/approved_dishes.txt
```

### 4.6 candidate tags 的处理规则

- `candidate_tags` 的意义是“Gemini 觉得有用，但当前 canonical dictionary 还接不住的词”。
- 处理原则是先审查，再决定是否收编，不能自动进正式字典。
- 新线程里的 AI 在处理 candidate tags 时，应该按这个顺序：
  - 先看这个词是否其实已有同义 canonical tag，只是 alias 没补上
  - 如果只是别名问题，优先补 alias，不要新增 canonical tag
  - 如果是复合词，优先拆成已有原子 tags，不要直接存复合词
  - 只有当这个词确实表达了新的稳定概念、会反复出现、且对推荐有价值时，才新增 canonical tag
- 新增 canonical tag 时，必须同时补齐：
  - 所属 dimension
  - 英文 canonical key
  - 中文展示名
  - alias 映射
  - 必要的 decomposition 规则
  - prompt 中的 canonical dictionary

### 4.7 后续 AI 线程的执行要求

- 如果任务是“补新菜”：
  - 默认走人工审核菜名 -> `seed-names` -> 检查生产数据的流程。
- 如果任务是“补标签”：
  - 默认只更新标签，不重跑图片，优先使用 `--skip-images`。
- 如果任务是“看 candidate tags”：
  - 默认先整理候选词，再决定是补 alias、补拆分规则，还是新增 canonical tag。
- 如果任务涉及标签系统改动：
  - 先改 `backend/app/tagging.py`
  - 再检查 `backend/app/main.py`、`backend/scripts/dish_cache_admin.py`、App 展示层是否需要同步
  - 修改后至少跑后端测试；如果改到 iOS 展示，也要重新 `build`
- 如果任务涉及生产环境：
  - 先确认 Railway 部署成功
  - 再验证 `/health`
  - 再验证 `/v1/taste/deck`
  - 最后抽查数据库中的 `tags_json`
