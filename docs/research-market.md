# NotchCue 市场调研：桌面提词器的付费点、口播工具矩阵与用户痛点

> 调研日期：2026-10-14。本文承接 `docs/research-competitors.md`（下称“竞品报告”），那份报告已经讲过的阅读体验和语音跟随细节，这里不再重复，只在需要时引用。
> 标注说明：**[已核实]** 指来自官网、定价页、App Store 或 Microsoft Store 页面、官方帮助中心；**[第三方]** 指评测、博客、下载站，其中很多作者本身就是竞品厂商，已逐条注明；**[坊间]** 指用户评论或论坛，属于个例；**[推断]** 是我根据资料做的判断。查不到的内容写“查不到”，矩阵里不确定的格子写“?”。
> 局限：Reddit、小红书无法抓取，所以用户声音主要来自 App Store 评论、知乎、厂商博客和学术研究，覆盖面有限。

---

## 一页结论

1. **桌面提词器最主要的付费点是“语音跟随”，其次是 AI 改稿、录制和排练反馈。** 能核实的产品里，语音跟随要么整体收费（getcta Pro），要么限量免费：Avocado 免费版每周 3 次，CueNotch 免费版每天 3 次、每篇不超过 100 词，Speakflow 免费版是“limited Flow”。PromptSmart 甚至按语言单卖识别包，每种 $29.99，其中包括普通话。第二梯队的付费点依次是 AI 改稿（getcta、CueNotch、Avocado、芦笋、Teleprompter.com）、录制和去水印（Teleprompter.com、Avocado、Speakflow），以及排练报告（Avocado、CueNotch、Mootch）。[已核实]
2. **“刘海 + 有声即滚”已经免费化，单靠这个收不到钱。** Textream、NotchPrompter、Mootch、Snotch 都免费或开源，也都带某种语音滚动。付费产品能卖出去，靠的是跟随质量和这一步之外的工作流。这两年冒出来的 Mac 刘海提词器至少有 10 款，CueNotch、getcta、Avocado 已经把 AI 改稿做进 Pro。[已核实 + 推断]
3. **我们最大的差异化是 Mac 上的中文和中英混排逐字跟随，并且即兴发挥时不乱跳。** 有明确语言列表的 Mac 刘海或桌面竞品里，没有一家写明支持中文：Notchie 只支持英文，NotchPrompter 支持 8 种语言但不含中文，Elgato Voice Sync 只支持英文，Textream 的中日韩跟踪失效（见竞品报告）。国内的芦笋提词器在 Win/Mac 上有“智能跟读”和“隐形提词”，但没有贴近镜头的视线角度设计，跟随质量也查不到。第二个差异化是**按视线研究把卡片放在镜头下方 3–7°**。眼神问题有实验证据：线上面试中视线下垂，评分甚至低于只有声音的版本（Scientific Reports 2024）。竞品只说“放在刘海附近”，没有一家把角度做成可调的产品能力。[已核实 + 推断]
4. **我们最大的缺口是只覆盖了“念稿”这一步。** 中国口播创作者真正付费的是剪映 SVIP（¥499–758/年，各报道数字不一）和开拍 SVIP（¥699/年）这样的整条流水线：AI 写稿、提词录制、自动字幕、去口癖和去 NG、出封面。Descript、Captions、BIGVU、Riverside 在英文市场也是同样的打法，提词器只是入口，钱收在 AI 后期，例如眼神矫正、去填充词、去重录。[已核实]
5. **最值得先做的付费点有三个，都是“念稿前后”的小闭环，不必去做剪辑器。** [推断]
   - **AI 口语化改稿和按时长裁稿。** 写稿是公认门槛，Wyzowl 2026 年调查里“不知从何开始”占 10%。LLM 成本低，竞品已经验证有人愿意付钱。
   - **排练报告。** 我们已经有实时语速，可以扩展为“每段语速、卡顿处、即兴段落、漏读句”的会话报告。Avocado 和 CueNotch 都把这个放进 Pro。
   - **对齐数据导出。** 我们知道每句话什么时候念、念没念，可以导出 SRT 字幕或 take 标记，给剪映“文稿匹配”或 Descript 用，正好接上用户最痛的后期环节。Mootch 已经在做 SRT/VTT 导出。
6. **价格带比较清楚，中文用户的心理价位不低。** 英文 Mac 刘海类大多是买断 $4.99–39（NotchPrompter $4.99、Notchie 和 CueNotch $29.99、Moody $39），订阅 $7.99–9/月（Avocado、getcta），高价买断 $99.99–159.99（VoicePrompter、Teleprompter Pro），跨平台套件约 $90/年（Teleprompter.com）。中文市场里，芦笋终身版约 ¥299.9（2023 年第三方数据），轻抖手机年卡 ¥388（见竞品报告），剪映和开拍 SVIP 都在 ¥500–700/年。App Store 评论里抱怨最多的是“订阅贵”和“试用后被扣年费”，所以**提供买断选项是加分项**。[已核实 + 坊间]
7. **建议的定价结构** [推断]：
   - **免费版：** 匀速模式、两种布局、隐藏于屏幕共享、导入，再加每周若干次语音跟随（参照 Avocado 每周 3 次的做法，让用户先体验到差异化）。
   - **Pro：** 无限语音跟随、自定义词表（按稿件生成的语言模型）、排练报告、SRT 导出、遥控。买断价锚定 $29.99–39 或 ¥128–198，也可以另设低价月订阅。
   - **AI 改稿：** 有边际成本，单独用额度或加油包计费，参照 getcta 的 $5 加 80 次额度。

---

## Part 1：桌面提词器（Mac/Windows/Web），重点是付费产品

### 1A. Mac 刘海或桌面原生提词器

| 产品 | 平台 | 价格与模式 | 付费墙后面是什么 | 核心差异 | 语音跟随 | 中文 | 评分 | 主要抱怨 |
|---|---|---|---|---|---|---|---|---|
| **Moody** | Mac（macOS 15+） | **$39 买断**，一份授权覆盖自己的所有 Mac [已核实]；第三方报过 $59 和 $29，以官网为准 | 整个 App 收费，没有免费版 | 隐藏于共享和截图、屏幕录制、iPhone 遥控、Moody Cue 分段跳转、全部本地处理 | 有，有声即滚，悬停暂停 | 查不到 | 查不到 | 噪声会误触发（官方承认）；字区小，适合短内容 [第三方] |
| **Notchie** | Mac | **$29.99 买断**，无内购 [已核实] | 整个 App 收费 | 刘海提词、悬停暂停、脚本队列、隐藏于共享 | 有，有声即滚 | **只支持英文** [已核实] | 评分数不足，无法显示 | macOS 26 上 bug 多、像没人维护 [坊间，单条] |
| **NotchPrompter** | Mac（14.6+） | **App Store $4.99 买断**，GitHub 开源免费 [已核实] | 没有功能差异，付费等于赞助 | 开源、OpenDyslexic 字体、多显示器 | 有，有声即滚 | 支持 8 种语言，**不含中文** [已核实] | 评分数不足 | 语音激活失灵（2.6.1 已修）[坊间] |
| **CueNotch** | Mac（14+） | **$29.99 买断**或 **$7.99/周**；3 天试用，不自动续费 [已核实-官网] | 免费版每天 3 次、每篇不超过 100 词。**Pro 包括 Ghost Mode（隐藏于共享）**、Magic Polish（AI 去填充词、润色）、Rehearsal Coach（排练时看停顿、语速、坐姿和取景）、Memorize（背稿）、实时字幕 | AI 润色加排练教练 | 有，逐词，宣称跳句后能找回位置 | 查不到 | 查不到 | 查不到；它的博客是竞品对比，只能当线索 |
| **Avocado** | Mac（14+）、iPhone、iPad | 核心免费；**Pro $7.99/月或 $79.99/年** [已核实] | **语音滚动和自适应速度**（免费版每周 3 次）、AI Agent（可以从 Claude、Cursor、Codex 写稿改稿）、AI Smart Cues、Director Mode、录制、完整的排练历史和 Delivery Coaching | 把 AI 和排练分析做成订阅 | 有，会学习用户语速 | 查不到 | 查不到 | 查不到 |
| **getcta.store** | Mac（Win/Linux 即将推出） | 免费；**Pro $9/月**（含 60 次 AI 额度）；加油包 $5/80 次 [已核实] | **语音跟随**、全部 AI 工具（从笔记生成稿子、改得更好念、按时长裁剪）、从 Notion 或 Google Drive 导入 | “刘海加 AI 写稿”，AI 按额度计费 | 有，逐词高亮，跳读后能追上 | 查不到 | 查不到 | 查不到 |
| **VoicePrompter** | Mac（15+），也在 Setapp 上架 | 免费版限 3 篇稿子；**Pro $3.34/月，终身 $99.99** [已核实] | 3 篇以上的稿子 | 宣称支持 60+ 种语言，`[方括号]` 跳过 | 有，基于 Apple 识别 | 宣称 60+ 种语言，但没有点名中文 | 查不到 | 查不到 |
| **Mootch** | Mac（14+），附 iOS 遥控 | **完全免费**，接受捐赠 [已核实] | 无 | 本地 Whisper 识别、重复词处理、噪声过滤、排练和填充词教练、PPT 自动翻页、导出 SRT/VTT | 有，逐词 | 查不到 | 查不到 | 查不到 |
| **Textream** | Mac、iOS | 免费，MIT 开源 | 无 | 逐词高亮、Director 模式 | 有，有三种模式 | **CJK 跟踪失效**（见竞品报告） | 不适用 | 见竞品报告 |
| **Teleprompter Pro**（原名 Teleprompter Premium） | iOS、Mac；Windows 上有同名 App，开发者是否相同不确定 | 免费；**Pro $59.99/年或 $159.99 终身** [已核实] | 导入 Word、PDF、txt、rtf（免费版只能导入 5 次）、高级遥控、HDMI/AirPlay 纯净输出 | 富文本、硬件提词器和踏板 | 官网没写；Windows Store 同名 App 称有语音识别 | 查不到 | 查不到 | 查不到 |
| **PromptSmart Pro**（Mac） | Mac、iOS | 第三方称买断 $29.99，另有可选的 $34.99/年 [第三方-竞品 Avocado] | 用户说“关键功能要再订阅” | VoiceTrack | 有 | 见 1B | **3.9/5，53 个评分**（Mac）[已核实] | “Bait and switch”、只卖年费、难退订、跟随时走时停、崩溃 [坊间，多条] |
| **VODIUM** | Mac、Windows | 约 $15/月，7 天试用 [第三方-竞品] | 整个 App 订阅 | 面向视频会议，窗口贴在摄像头下方 | 第三方称**没有**，只有匀速 | 查不到 | 查不到 | 打开 PPT 后窗口消失 [坊间] |
| **PromptDog** | Win、Mac | **$99 买断，现促销价 $69**；一份授权装 2 台电脑；10 天试用，30 天退款 [已核实] | 整个 App 收费 | 双屏操作员窗口，面向硬件提词器 | 没有，只能手动 | 支持 UTF-8，中文跟随不适用 | 查不到 | 查不到 |

### 1B. 跨平台、网页与硬件

| 产品 | 平台 | 价格与模式 | 付费墙后面是什么 | 语音跟随 | 中文 | 评分与抱怨 |
|---|---|---|---|---|---|---|
| **Teleprompter.com** | iOS、Android、Mac（App Store 写明 macOS 12+）、Web | Starter 免费；**Pro $19.99/月，或按年折合 $7.5/月**；Max 按年折合 $24.99/月；Team 按席位收费 [已核实]。App Store 显示 Pro 年费 $89.99，有 7 天试用 | **去水印的 4K 录制、镜像、在另一台设备上预览、字幕生成、clean audio**。遥控和云存储免费 | 有（VoiceGlide） | 支持简体和繁体（见竞品报告） | **4.8/5，约 2.9 万个评分**；抱怨主要是 $89 太贵、试用后被扣费、多个 take 被合成一段、语速只能拖滑块 [坊间] |
| **PromptSmart+** | iOS、Android、Web | **$8.99/月或 $79.99/年**；**语言包每种 $29.99**，含普通话 [已核实] | 大部分高级功能要订阅或试用；Teams 档才有无限 Control Room | 有（VoiceTrack，15 种语言） | 有普通话语言包 | **4.5/5，560 个评分**；抱怨忘了退订被扣年费、跑题后只有约 80% 能追回 [坊间] |
| **Speakflow** | Web（Windows 桌面版 beta 随 Plus 提供） | Free；**Plus 按年折合 $15/月**；Studio 按年折合 $99/月；另有 7、30、90 天的 Plus Pass [已核实] | **无限 Flow 语音滚动**、录制（1 小时存储）、**Overlay（可叠在 Zoom、Meet、Teams 上的提词器）**、语音命令、多设备同步、协作 | 有，免费版限量 | 查不到 | 查不到 |
| **BIGVU** | iOS、Android、Web（desk.bigvu.tv） | Free（720p 带水印，每段 9 分钟）；Starter $12/月；**AI Pro $19/月**；Max $49/月 [已核实] | 去水印和 1080p 在 Starter；**AI 眼神矫正**、4K、剪辑器、AI 配音在 AI Pro；AI 分身（AI Twin）在 Max。提词器和 AI 写稿**免费版就有** | 只检测停顿，不识别词（见竞品报告） | 查不到 | 查不到 |
| **Elgato Prompter 加 Camera Hub/Studio 2.0** | Win、Mac 加硬件 | 硬件约 $249.99–299.99（各零售商报价不一）[第三方]；软件价格在官方文章里查不到 | 相当于为硬件付钱 | 有 Voice Sync，带灵敏度滑块 | **只支持英文**，德语在计划中 [已核实] | 查不到 |
| **Autocue QStart** | Windows（Mac 版随硬件附送） | Windows 版自 2016 年起免费；加密狗版收费 [第三方-媒体和零售商] | 加密狗授权 | 没有 | 查不到 | 不适用 |
| **OBS 插件**（merkrahq/obs-teleprompter、Prompter Studio 等） | Win、Mac | 免费，第三方插件 | 无 | **没找到能用语音跟随的 OBS dock**；Glanceline 这类伴侣 App 才有 [第三方] | 查不到 | OBS 升级后插件容易失效 |

### 1C. 自带提词器的录制或剪辑套件（提词器不是付费点）

| 产品 | 提词器情况 | 价格（付费档） | 提词器所在档位 |
|---|---|---|---|
| **Descript** | 内置，**按时间滚动，不跟语音**（官方帮助中心）；桌面版里提词窗口不会被录进画面 | Hobbyist $16/$24、Creator $24/$35、Business $50/$65 每月（年付/月付，“哪个是年付”是我推断的）[已核实] | 免费版就有；**眼神矫正和去填充词**在免费版受限，付费档完整 |
| **Riverside** | 内置，可调速度、可手动滚动 | Pro $24–29/月、Grow $34–39/月（抓到的是官网的 staging 页面）[已核实，需复核] | **Pro 才有提词器**（仅主持人可用），Business 才能共享给嘉宾；眼神矫正也从 Pro 起 |
| **Loom** | 桌面端有“Speaker notes”静态窗口（最多 1 万字）；新版 Mac 公告提到内置提词器，但帮助文档里没有核实到 | Business $18、Business+AI $24 每用户每月 [已核实] | 所有档都有 Speaker notes；**AI 和去填充词只在 Business+AI** |
| **Tella** | 定价页列出了“Teleprompter”，档位从页面上看不出来 | Pro $13、Premium $19 每用户每月（年付）[已核实] | ? |
| **Airtime Creator**（原 mmhmm） | Speaker Notes，只在桌面端，免费提供 | $10/月（年付）或 $12/月 [已核实-官方博客] | 包含在订阅内 |
| **Camo** | **没有内置提词器**；官方建议把 Camo 窗口设成透明，叠在其他提词器上面 [已核实-官方支持页] | 不适用 | 不适用 |

### 1D. 中文桌面方案

| 产品 | 平台 | 价格与模式 | 付费墙后面是什么 | 语音跟随 | 备注 |
|---|---|---|---|---|---|
| **芦笋提词器** | **Windows 10+、Mac（M 系列和 Intel）**、Android、iOS | 有免费版；会员分月、季、年、3 年、终身五档，官方价格页抓不到数字；2023 年第三方报终身版 ¥299.9 [第三方] | **所有档都有智能跟读和匀速**。会员差别在登录设备数（1→2→5 台）、**AI 提词灵感次数**（10→100→…→15000 次）、积分；3 年及以上档送遥控器，终身档送 OBS 课 [已核实-官方文档] | 有，“读到哪滚到哪” | **隐形提词**（直播、录屏、共享时不显示）；主打直播、录课、演讲。**这是国内电脑端最直接的竞品** |
| **剪映专业版**（Win/Mac） | 桌面 | SVIP 月费 ¥79，连续包年 ¥499–599，各报道数字不一 [第三方-IT之家等] | 知乎文章称识别字幕、提词器、降噪等功能要会员 [第三方，2024 年] | **桌面端有没有提词器没查到**；2021 年上线的提词器在移动端 [第三方] | 有智能剪口播（去停顿、去语气词、去重复）、智能文案、文稿匹配字幕 |
| **开拍**（美图） | 移动端，电脑版在公测 | SVIP 连续包年 ¥699（App Store 中国区）[第三方转引] | 第三方称“AI 语速提词”是会员功能 | 有，“AI 语速跟随”按词标记已读和未读 [第三方-疑似软文] | 一站式完成提词、录制、文字快剪（去 NG）、网感模板和封面 |
| **轻抖** | 移动端为主；Microsoft Store 上有同名条目，详情抓不到 | 手机年卡 ¥388（见竞品报告） | 查不到 | 有，AI 跟随 | 有没有正式电脑版，各来源说法不一 |

### “用户为什么付费”小结

按“有几家把它放进付费墙”排序：

| 排名 | 付费点 | 收费的产品 | 对我们的含义 [推断] |
|---|---|---|---|
| 1 | **语音跟随（不限次数，或者支持更多语言）** | Avocado、getcta、Speakflow、CueNotch（限量）、PromptSmart（按语言包）、开拍 | 这是最被认可的付费点，也正是我们的强项。中文和中英混排跟随可以当作“语言包”级别的价值来卖 |
| 2 | **AI 写稿和改稿**（口语化、润色、按时长裁剪、去填充词） | getcta、CueNotch、Avocado、Teleprompter.com、芦笋（按次数）、BIGVU、剪映、开拍 | 我们现在没有，但实现成本最低 |
| 3 | **录制、去水印、4K** | Teleprompter.com、Avocado、Speakflow、BIGVU、Riverside、Descript | 不一定要做完整录制，可以先做 take 标记加导出 |
| 4 | **排练反馈和历史**（语速、停顿、背稿） | Avocado、CueNotch、Mootch（免费） | 我们已经有实时语速，离这一步最近 |
| 5 | **遥控、导演模式、多设备** | Avocado、Teleprompter Pro、PromptSmart Teams、芦笋（按设备数） | 可以放在中期，需要做 iOS 端 |
| 6 | **隐藏于屏幕共享** | CueNotch 收费；Notchie、Moody、芦笋、NotchPrompter 都包含在内 | 已经是标配，不宜收费 |
| 7 | **导入格式、镜像、字幕** | Teleprompter Pro（导入）、Teleprompter.com（镜像、字幕） | 导入我们已免费提供，这是体验上的加分项 |
| 8 | **AI 后期**（眼神矫正、去填充词、去重录） | Descript、Riverside、BIGVU、Captions、Loom | 属于剪辑器的地盘，不建议正面去做 |

**价格带：**

| 价格带 | 代表产品 |
|---|---|
| 免费或开源 | Textream、NotchPrompter（GitHub 版）、Mootch、Snotch |
| 低价买断 $4.99 | NotchPrompter（App Store 版） |
| 主流买断 $29.99–39 | Notchie、CueNotch、Moody |
| 高价买断 $69–159.99 | PromptDog、VoicePrompter 终身版、Teleprompter Pro 终身版 |
| 订阅 $3.34–9/月 | VoicePrompter、Avocado、getcta |
| 订阅 $15–20/月（约 $80–90/年） | Speakflow、VODIUM、Teleprompter.com、PromptSmart+ |
| 中文市场 | 芦笋终身版约 ¥300 [第三方]；轻抖手机年卡 ¥388；剪映 SVIP ¥499–599/年；开拍 SVIP ¥699/年 |

---

## Part 2：做口播或 talking-head 视频的主力产品

### 功能矩阵

图例：Y 表示有；N 表示没有；? 表示查不到或不确定；“部分”的含义见括号。

| 功能 | 剪映专业版 / CapCut 桌面 | 开拍 | Descript | Captions | BIGVU | Riverside | Loom | Teleprompter.com | HeyGen（相邻品类） | **NotchCue** |
|---|---|---|---|---|---|---|---|---|---|---|
| AI 写稿和改写 | Y（智能文案、AI Writer） | Y [第三方] | ?（Underlord 能否写稿没核实到） | ? | Y（免费版就有） | ?（Co-Creator 写的是社媒文案） | N（Loom AI 写的是标题和摘要） | Y（AI 改写） | Y | **N** |
| 提词器 | ?（桌面端没查到；移动端 Y） | Y | Y | Y | Y | Y（Pro） | 部分（静态 Speaker notes） | Y | 不适用（数字人代替真人出镜） | **Y** |
| 语音跟随 | N / ? | Y（AI 语速跟随）[第三方] | N（按时间滚动，官方） | 部分（厂商称按语速滚动） | 部分（只检测停顿） | N | N | Y | 不适用 | **Y（中文拼音模糊匹配、中英混排、自定义词表、即兴时停住不跳）** |
| 眼神处理 | ? | ? | Y（后期 AI 矫正） | Y（后期 AI 矫正） | Y（AI Pro） | Y（Pro） | ? | ? | 不适用 | **部分（事前处理：卡片放在镜头下方 3–7°；没有后期矫正）** |
| 录制 | ? | Y | Y | Y | Y | Y | Y | Y | 不适用 | **N** |
| 自动字幕 | Y | Y | Y | Y | Y | Y | Y | Y（Pro） | Y | **N** |
| 去填充词、剪气口 | Y（智能剪口播） | Y（文字快剪） | Y | Y | ? | Y（Pro） | Y（Business+AI） | ? | 不适用 | **N** |
| 重录（take）管理 | Y（识别重复）[第三方] | Y（识别 NG）[第三方] | Y（Remove retakes） | ? | Y（每次重录存为一个 take） | ? | ? | 部分（多个 take 被合成一段，有用户抱怨） | 不适用 | **N（但即兴时停住不跳，是对齐层面的能力）** |
| 多设备、远程 | N | ? | Y（Rooms 远程录制） | ? | ? | Y（远程嘉宾；提词器共享要 Business） | N | Y（遥控、远程预览） | 不适用 | **N（只有全局热键和触控板）** |
| 排练、语速分析 | N | N | N | ? | 部分（社媒审计，不是排练分析） | N | 部分（观看数据，不是排练分析） | ? | 不适用 | **部分（实时语速提示、本地跟踪日志）** |
| 导出和发布 | Y（直连抖音） | Y | Y | Y | Y（社媒排期） | Y（Magic Clips） | Y（分享链接） | ? | Y | **N** |
| 提词时隐藏于屏幕共享 | 不适用 | ? | Y（桌面版提词窗口不会被录进画面） | ? | ? | ? | ? | ? | 不适用 | **Y** |
| 贴近镜头的笔记本刘海显示 | N | N | 部分（位置可调） | ? | 部分（字放在摄像头画面旁） | N | N | N | 不适用 | **Y** |

### 他们有、我们没有

- **AI 写稿和改稿**：几乎每家都有。
- **录制和 take 管理**：Teleprompter.com 用户明确要求“每个 take 单独保存”。
- **自动字幕、去填充词和气口、去 NG**：剪映、开拍、Descript 的核心卖点。
- **后期眼神矫正**：Descript、Captions、BIGVU、Riverside。
- **遥控和多设备**：Teleprompter.com、Riverside，以及竞品报告里的 Moody 和 PromptSmart。
- **云同步和团队协作**：Teleprompter.com、Speakflow、芦笋。
- **镜像**：用于硬件提词器，Teleprompter.com 等。
- **直接发布到平台**：剪映、BIGVU。

### 我们有、他们没有

- **中文和中英混排的逐字跟随**，包括拼音模糊匹配、多音字处理、数字归一化，以及**按稿件生成的自定义语言模型**（改善人名和中英术语的识别）。上表的套件里，有真正按词跟随的只有 Teleprompter.com 和开拍。Mac 刘海类里，没有一家写明支持中文。
- **即兴时停住不跳，漏识别时自动追上，由用户手动接管。** 这正好针对竞品报告里“跳行”“遇到重复短语跳到后面”的头号抱怨。
- **基于视线研究的卡片角度和 5 种摆放预设**，让眼神问题在录制时就避免，而不是靠后期矫正。
- **刘海状态岛加浮动卡片的双布局**，并且把文件拖到刘海上就能导入。
- **完全本地运行**：跟踪日志只存在本机。Moody、Mootch、CueNotch 也是本地，但套件类产品都依赖云端。

### 大家都有（标配）

- 匀速滚动，速度、字号、颜色可调
- 倒计时
- 导入 txt 或 docx（只有 Teleprompter Pro 把导入放进付费墙）
- 热键或快捷键控制
- 悬停或空格暂停
- 隐藏于屏幕共享（刘海类基本都有）
- 有声即滚的基础语音模式

---

## Part 3：用户画像与核心痛点

### 画像表

| 画像 | 典型场景 | 设备 | 语言 | 频率 | 付费意愿 | 主要痛点与证据 |
|---|---|---|---|---|---|---|
| **A. 中文知识或科技博主**（B 站、YouTube、小红书、抖音） | 在 MacBook 前录 3–15 分钟的口播，之后用剪映剪 | 笔记本摄像头最常见，进阶用户接相机 | 中文为主，**中英术语混杂**（产品名、API、英文缩写） | 每周 1–7 条 | **高**：已经在为剪映或开拍 SVIP 付 ¥500–700/年 | 忘词、眼神飘、念稿感（知乎多篇 [第三方，多为推广文]）；后期剪气口很费时，“5 分钟素材光删废话就要约 20 分钟” [第三方，疑似开拍软文]；英文术语识别差 [推断，佐证是 Textream CJK 问题] |
| **B. 课程创作者和老师**（网课、录课、企业培训） | 一边录屏一边讲，或者对着镜头讲课，稿子长 | 笔记本加外接麦克风，常配双屏 | 中文，或中英混排 | 批量录制，按周或按项目 | 中到高（芦笋主打录课和 OBS 课） | 长稿件会跟丢；提词窗口不能被录进画面（芦笋“隐形提词”是卖点 [已核实]）；苹果识别有约 1 分钟限制（见竞品报告） |
| **C. B2B 营销人员和创始人** | 产品演示、融资视频、LinkedIn 视频 | MacBook，偶尔租棚 | 英文；中国出海团队用中英混排 | 每月几条 | 中到高（Descript、Riverside 每月 $24–35） | 怕看起来在读稿；需要一次念对或方便重录；后期眼神矫正“还行但不算出色” [坊间，Descript 用户] |
| **D. 销售做异步视频**（Loom 式外联） | 针对每个客户录 1–3 分钟的个性化视频 | 笔记本摄像头 | 英文 | 每天多条 | 中，通常公司付费（Loom $18–24 每人每月） | Loom 只有静态 Speaker notes [已核实]；既要个性化又要不像念稿；视频外联能提升回复率（Intercom 案例称 +19% [厂商]） |
| **E. 直播和带货主播** | 电脑开播，话术按商品分段 | 电脑加直播伴侣或 OBS，摄像头或相机 | 中文 | 每天，每次数小时 | 中（会买遥控器和终身会员） | 话术记不住、冷场；提词不能出现在直播画面里；按商品分段跳转 [第三方-知乎推广文、芦笋文档] |
| **F. 远程工作者、会议演讲者** | Zoom、Teams 汇报，路演，网络研讨会 | MacBook 内置摄像头 | 中文或英文 | 每周 | 低到中（Airtime $10/月，VODIUM 约 $15/月） | 看讲稿时视线下垂，共享屏幕时讲稿被别人看到（Notchie、CueNotch、Moody 都主打这一点） |
| **G. 求职者**（单向视频面试，例如 HireVue） | 录制回答，限时 | 笔记本摄像头 | 英文或中文 | 求职期集中使用 | 低，一次性 | **视线下垂会被扣分**：Scientific Reports 2024 实验中，视线下垂的评分甚至低于只有声音 [已核实]；招聘方能看出在读稿（Glassdoor 招聘者回答 [坊间]）。注意：用提词器存在合规和伦理边界 |
| **H. 以英语为第二语言、要录英文视频的人** | 中国人录英文产品视频、课程或面试 | 笔记本 | 用英文念稿，母语是中文 | 中 | 中 | 口音会让英文识别更容易丢位 [推断]；需要语速和停顿提示；英文卡片显得字少（见竞品报告英文专项） |

### 跨画像的 TOP 8 痛点与 NotchCue 覆盖情况

| # | 痛点 | 涉及画像 | 证据（可靠性） | NotchCue 覆盖 |
|---|---|---|---|---|
| 1 | **忘词、背稿压力** | 全部 | 知乎多篇 [第三方]；这是提词器品类存在的前提 | **已解决** |
| 2 | **眼神飘，被看出在读稿** | A、C、D、F、G | Scientific Reports 2024：12 名被试、38 名评估者，视线下垂的评分低于只有声音的版本 [已核实]；厂商博客一致认为“行太宽、离镜头太远”是主要破绽 [第三方]；知乎“斜眼看稿” [第三方] | **大部分解决**：卡片放在镜头下方 3–7°，行宽可控。**缺口**：没有后期矫正，也没有“视线偏离提示” |
| 3 | **滚动和人对不上**：匀速滚动要么抢跑要么拖后；语音跟随会丢位、跳行、遇到重复短语跳到后面 | A、B、C、E | PromptSmart Mac 评论“走走停停”，3.9/5 [坊间]；Teleprompter.com 评论“相似短语会跳到前面” [坊间]；竞品报告的抱怨清单 | **已解决（核心能力）**：即兴时停住不跳、漏识别时追上、热键接管。需要用真实口播稿回归测试，确认质量 |
| 4 | **中文和中英混排识别差**，Mac 竞品大多只支持英文 | A、B、E、H | Notchie 只支持英文，NotchPrompter 不含中文，Elgato 只支持英文 [已核实]；Textream CJK 失效 [已核实-issue] | **已解决（最大差异化）** |
| 5 | **后期太耗时**：剪气口、删 NG、配字幕 | A、B、C | 剪映、开拍、Descript 都把这一项作为主卖点 [已核实]；Wyzowl 2026：不做视频的营销人员里 19% 说“没时间” [已核实-调查，样本 266] | **未解决**。最低成本的切入方式是导出 SRT 和 take 标记，交给剪映或 Descript [推断] |
| 6 | **写稿难，写出来不像人话（念稿感）** | A、C、D、H | AI 写稿几乎是每家的标配 [已核实]；Wyzowl：10% 不知从何开始 [第三方转引]；知乎建议“用提纲代替逐字稿” [第三方] | **未解决**。“AI 口语化改写加按时长裁剪”是最值得先做的付费点 |
| 7 | **提词内容出现在直播或共享画面里** | B、E、F | 芦笋“隐形提词”、CueNotch Ghost Mode 收费、Notchie 和 Moody 主打 [已核实] | **已解决**（隐藏于屏幕共享） |
| 8 | **订阅太贵，试用后被扣年费** | 全部 | PromptSmart（Mac）“只卖年费、难退订”，Teleprompter.com“$89 太离谱” [坊间，多条] | **可以借机差异化**：提供买断或终身版 [推断] |

另外两个值得关注的需求：
- **按语速和停顿给排练反馈。** Avocado、CueNotch、Mootch 已经在做。我们有实时语速，属于**部分覆盖**。
- **重录时快速回到某一句。** Teleprompter.com 评论里有人提到“每个 take 单独保存”。我们只有手动热键，属于**部分覆盖**。

---

## 证据表

| 结论 | 来源 | 可靠性 |
|---|---|---|
| Moody 买断 $39，不订阅，需要 macOS 15+，有屏幕录制和 iPhone 遥控 | https://moody.mjarosz.com/ | [已核实] |
| Moody 第三方报价 $59 或 $29，与官网不一致 | https://www.trustedreviews.com/news/this-app-turns-your-macbooks-notch-into-something-very-useful 、https://sharespeak.co/teleprompter-pricing-comparison | [第三方] |
| Notchie 买断 $29.99，只支持英文，评分数不足；有用户说在 macOS 26 上 bug 多 | https://apps.apple.com/us/app/notchie/id6756745307?mt=12 | [已核实] / 评论为 [坊间] |
| NotchPrompter 在 App Store 卖 $4.99，在 GitHub 开源；支持 8 种语言，不含中文 | https://apps.apple.com/us/app/notchprompter/id6760967658?mt=12 、https://notchprompter.com/ | [已核实] |
| CueNotch 买断 $29.99 或 $7.99/周；免费版每天 3 次、每篇不超过 100 词；Ghost Mode、Magic Polish、Rehearsal Coach 属于 Pro | https://cuenotch.com/ | [已核实-官网] |
| Avocado Pro $7.99/月或 $79.99/年；免费版每周 3 次语音滚动；AI Agent、Director Mode、录制属于 Pro | https://avocadonotch.com/ 、https://avocadonotch.com/pricing | [已核实] |
| getcta Pro $9/月，语音跟随和 AI 写稿属于 Pro；额度包 $5/80 次 | https://getcta.store/ | [已核实] |
| VoicePrompter 免费版限 3 篇稿子；Pro $3.34/月，终身 $99.99；宣称支持 60+ 种语言 | https://voiceprompter.app/mac/ | [已核实] |
| Mootch 完全免费，用本地 Whisper，可导出 SRT/VTT，带填充词教练 | https://getmootch.com/ | [已核实] |
| Teleprompter Pro（原 Teleprompter Premium）$59.99/年或 $159.99 终身；导入 Word/PDF 属于 Pro | https://teleprompterpro.com/pricing 、https://teleprompterpro.com/features | [已核实] |
| Teleprompter.com 定价：Starter 免费、Pro $19.99/月或按年 $7.5/月；4K 去水印、镜像、字幕属于 Pro | https://www.teleprompter.com/pricing | [已核实] |
| Teleprompter.com 在 App Store 4.8/5、约 2.9 万个评分，支持 macOS 12+；有“$89 太贵”、试用扣费、take 合并的抱怨 | https://apps.apple.com/us/app/teleprompter-com/id1420515755 | [已核实] / 评论为 [坊间] |
| PromptSmart+ 每月 $8.99 或每年 $79.99；语言包每种 $29.99（含普通话）；4.5/5，560 个评分 | https://apps.apple.com/us/app/promptsmart/id1526733375 | [已核实] |
| PromptSmart Pro（Mac）3.9/5，53 个评分；用户抱怨“bait and switch”、只卖年费、跟随走走停停 | https://apps.apple.com/us/app/promptsmart-pro-teleprompter/id894811756?see-all=reviews&platform=mac | [已核实] / [坊间] |
| PromptSmart Pro（Mac）买断 $29.99，另有可选 $34.99/年 | https://avocadonotch.com/blog/best-teleprompter-app-mac-2026 | [第三方-竞品] |
| Speakflow 的 Plus 按年折合 $15/月；无限 Flow、录制、Zoom Overlay 属于 Plus | https://www.speakflow.com/pricing | [已核实] |
| BIGVU 定价：AI Pro $19/月，含 AI 眼神矫正；提词器和 AI 写稿免费；Web 端可以用摄像头录制 | https://bigvu.tv/pricing 、https://faq.bigvu.tv/en/article/record-with-the-teleprompter-web-m8tnjf/ | [已核实] |
| PromptDog $99 买断（促销价 $69），一份授权装 2 台电脑，没有语音滚动 | https://promptdog.com/ | [已核实] |
| VODIUM 约 $15/月，没有语音跟踪 | https://sharespeak.co/best-teleprompter-windows 、https://www.speakflow.com/compare/vodium | [第三方-竞品] |
| Elgato Voice Sync 只支持英文，德语在计划中；有灵敏度滑块 | https://www.elgato.com/us/en/explorer/products/teleprompter/elgato-studio-2-0-the-prompter-experience-rebuilt/ | [已核实] |
| Elgato Prompter 硬件约 $249.99–299.99 | https://teleprompter.works/blog/elgato-prompter-review/ 、https://www.sweetwater.com/store/detail/ElPrompter--elgato-prompter | [第三方] |
| Autocue QStart Windows 版自 2016 年起免费 | https://www.tvtechnology.com/equipment/autocue-offering-qstart-telepromter-software-for-free | [第三方-媒体] |
| 没找到支持语音跟随的 OBS 提词器 dock | https://github.com/merkrahq/obs-teleprompter 、https://github.com/CrisioDev/glanceline | [第三方] |
| Descript 提词器按时间滚动，不跟语音；桌面版提词窗口不会被录进画面 | https://help.descript.com/hc/en-us/articles/35482375421581-Record-with-Descript-s-built-in-teleprompter | [已核实] |
| Descript 定价，眼神矫正和去填充词在免费版受限 | https://www.descript.com/pricing | [已核实]（年付/月付的对应关系是 [推断]） |
| Descript 有 Remove retakes | https://www.descript.com/templates/remove-retakes-nu0kQZ | [已核实] |
| Riverside 的提词器和眼神矫正从 Pro 起；Business 才能把提词器共享给嘉宾 | https://riverside.com/pricing 、https://support.riverside.com/hc/en-us/articles/26539024815005-Fix-gaze-for-natural-eye-contact | [已核实]（价格来自 staging 页面，需复核） |
| Loom Speaker notes 只在桌面端、最多 1 万字；AI 和去填充词只在 Business+AI | https://support.atlassian.com/loom/docs/use-speaker-notes/ 、https://www.loom.com/pricing | [已核实] |
| Tella Pro $13、Premium $19 每用户每月（年付） | https://www.tella.com/pricing | [已核实] |
| Airtime Creator（原 mmhmm）$10–12/月，带 Speaker Notes | https://www.airtime.com/blog/mmhmm-becomes-airtime 、https://help.airtime.com/hc/en-us/articles/33869542965783-Use-Speaker-Notes-to-present-with-Airtime-Creator | [已核实] |
| Camo 没有内置提词器，官方建议把透明窗口叠在提词器上 | https://camo.com/support/how-to/make-eye-contact-on-video | [已核实] |
| Captions（Mirage）有 Mac 版、提词器、AI 眼神矫正和去填充词 | https://help.mirage.app/docs/visual/eye-contact 、https://captions.ai/ | [已核实-厂商] |
| CapCut 桌面版有 AI Writer 和识别填充词功能 | https://www.capcut.com/tools/filler-words 、https://www.capcut.com/tools/desktop-ai-power | [已核实-厂商] |
| 芦笋提词器支持 Win/Mac/移动端；所有档都有智能跟读；会员按设备数和 AI 提词灵感次数分档；有隐形提词 | https://docs.lusun.com/tcq/basic/vip.html 、https://tcq.lusun.com/ | [已核实] |
| 芦笋终身版 ¥299.9（2023 年） | https://www.partnershare.cn/product/lu-sun-ti-ci-qi （下载站转述） | [第三方] |
| 剪映 SVIP 包年 ¥499–599（2024），另有报道称已涨价；手机和电脑通用 | https://www.ithome.com/0/778/162.htm 、https://www.ithome.com/0/906/538.htm | [第三方-媒体] |
| 剪映提词器 2021 年在移动端上线；桌面端提词器没查到 | https://baike.baidu.com/item/%E5%89%AA%E6%98%A0/23816262 | [第三方] |
| 剪映有“智能剪口播”（去停顿、语气词、重复） | https://jingyan.baidu.com/article/d169e186140896026711d820.html | [第三方] |
| 开拍 SVIP 连续包年 ¥699；电脑版在公测；“AI 语速跟随”按词标记 | https://www.kaipai.com/pricing 、https://news.qq.com/rain/a/20260515A0AFQM00 | [第三方]（腾讯新闻文章疑似软文） |
| 度加剪辑有跟随模式的提词器和“快速剪辑”（去气口、语气词） | https://app.mi.com/details?id=com.baidu.tzeditor | [已核实-应用商店描述] |
| 在线面试中视线下垂会降低评分，甚至低于只有声音的版本 | https://www.sciencedaily.com/releases/2024/06/240617210530.htm （原文发表于 Scientific Reports, s41598-024-60371-5） | [已核实-学术，小样本] |
| Wyzowl 2026：不做视频的营销人员中 19% 说没时间 | https://wyzowl.com/video-marketing-statistics/ | [已核实-调查，样本 266] |
| Intercom 用 Loom 后，冷邮件回复率提升 19% | https://www.loom.com/customers/intercom | [第三方-厂商案例] |
| 招聘方能看出候选人在读稿，看笔记本身没问题 | https://www.glassdoor.com/Community/ask-a-recruiter-tech/is-it-acceptable-to-look-at-notes-during-a-virtual-interview-ive-been-outlining-my-experiences-using-the-star-method-and | [坊间] |
| HeyGen Creator $29/月；Synthesia Starter $29/月 | https://www.heygen.com/pricing 、https://www.synthesia.io/pricing | [第三方汇总，需复核] |
| 中文口播用户的痛点是忘词、眼神飘、念稿感 | https://zhuanlan.zhihu.com/p/2018039137198941112 等 | [第三方，多为推广] |
| 各项付费点优先级、定价建议、SRT 导出的切入点 | 本文综合判断 | [推断] |

**查不到：** Moody、Avocado、CueNotch、getcta 的识别语言是否含中文；剪映专业版桌面端是否有提词器；芦笋和开拍的当前官方价格；Teleprompter.com 免费版是否包含 VoiceGlide；Captions 和 Tella 各档位的具体功能；Elgato Studio 软件本身是否收费；Moody、Avocado、CueNotch、getcta 的评分（App Store 上评分数不足，或者不在 App Store 销售）。
