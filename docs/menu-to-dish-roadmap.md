# Menu To Dish Roadmap

## 目标
- 当前阶段：口味学习使用本地预制菜库，Gemini 仅用于口味分析。
- 下一阶段：用户上传菜单图片后，再由 Gemini 从菜单中抽取可点菜品并生成推荐候选。

## 预期流程（后续实现）
1. 用户在点菜页上传菜单图片（拍照或相册）。
2. 后端调用 Gemini 做菜单结构化解析。
3. 后端返回 `menu_items`（菜名、价格、描述、可选标签）。
4. App 用本地口味画像 + Gemini 分析结果做排序推荐。
5. 前端展示“推荐理由 + 避雷提醒 + 替代方案”。

## 数据结构草案

### 菜单解析结果
```json
{
  "menu_items": [
    {
      "name": "宫保鸡丁",
      "price": "38",
      "description": "微辣，花生，鸡丁",
      "tags": ["spicy", "chicken", "stir_fried"]
    }
  ],
  "source": "gemini"
}
```

### 推荐结果
```json
{
  "recommendations": [
    {
      "name": "宫保鸡丁",
      "score": 0.86,
      "reason": "你偏好辛辣、爆炒和鸡肉",
      "risk": "含花生，若忌口请跳过"
    }
  ]
}
```

## API 草案（后续）
- `POST /v1/menu/parse`
- `POST /v1/menu/recommend`

## 关键约束
- 菜名去重：同名不同写法要归一化（简繁/空格/别名）。
- 低质量菜单保护：如果识别置信度太低，提示用户重拍。
- 成本控制：只在上传菜单后调用 Gemini，不在日常滑卡阶段调用。
