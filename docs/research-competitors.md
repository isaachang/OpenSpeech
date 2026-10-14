# NotchCue 竞品与阅读体验调研

> 调研日期：2026-10-13。标注说明：**【已核实】** 指信息来自官网、App Store 页面、官方帮助中心或 GitHub 仓库或 issue 原文；**【第三方】** 指来自评测或博客，其中不少作者本身就是竞品厂商，已逐条注明；**【坊间】** 指用户评论或论坛内容，属于个例；**【推断】** 是我根据资料做的计算或判断，没有直接来源。查不到的内容一律写“查不到”。

---

## 一句话结论

英文卡片显得“字太少”，问题出在宽度用“汉字数”来定义。12–14 个汉字宽的卡片只装得下约 25 个拉丁字符，也就是 4–5 个英文词。业界对英文提词的共识是每行 **5–8 词**（约 30–42 字符）。按语速换算，英文一行停留约 1.8 秒，中文约 3.4 秒，所以英文换行频率高了将近一倍。解决办法是改用物理宽度（pt/cm）定义卡片，中英文各设默认容量，英文卡片加宽约 35–45%，或者略微缩小英文字号。
在语音跟随上，竞品被抱怨最多的是三件事：跳行或丢位后找不回、cue 被当作正文去匹配、中文分词出错。NotchCue 的拼音模糊对齐方向是对的，但这几处需要专门做好。

## 最该借鉴的 7 件事（按优先级）

1. **用物理宽度定义卡片，中英文分别设默认容量。** 英文目标是每行 6–8 词，约 36–42 字符；中文目标是每行 13–16 字。
   依据：Avocado 建议每行 5–8 词，并以 cm 给出行宽和视线扫动角【已核实-厂商博客】；MeyerPro 建议 8–10 词【已核实-行业博客】；广播稿常用每行 30–40 字符【第三方】；Netflix 字幕规范是英文 42 字符/行、简体中文 16 字/行【已核实】。具体换算见下文“英文显示专项”。
2. **已读、当前、未读三态着色，并固定一条阅读线。** 已读文字变暗或变灰，当前词或字高亮，未读保持亮色；当前行固定在镜头下方的某一行，不跟着内容上下漂移。
   依据：VoiceScroll 的当前词填色、已读变灰【已核实-App Store】；Elgato Studio 2.0 的已读变暗加 reading position 滑块【已核实-官方】；Teleprompter.com 的 Cue Indicator 会把正在说的词钉在固定行【已核实】；Textream 默认把活动行放在摄像头正下方【已核实-README】；灵感提词器 3.6 版的已读/未读区分【已核实-App Store 更新日志】。
   NotchCue 目前只高亮后面约 2 个字，可以再加上已读变暗，这样视线回落时能马上找到位置。
3. **在整篇稿子里重定位，并提供一键回到当前位置的手段。** 识别结果要能匹配到全文任意位置，向前和向后都要能找回，而不只是在当前位置附近找。同时提供三种手动纠正方式：热键、点击任意词跳转、语音命令（类似 Teleprompter.com 的 “Go current”）。前瞻窗口要做成可调。
   依据：Teleprompter.com 的 “Go current” 命令【已核实】；Textream 的 tap-to-jump【已核实】和 issue #46（用户反馈前瞻窗口只有约 5–6 个词，希望能调）【已核实-issue】；PromptSmart 用户抱怨“跳过好几页”“遇到重复短语就跳到下一处”【坊间-App Store 评论】；VoicePrompter 博客说 Teleprompter.com 只能向前跟随【第三方-竞品作者】。
4. **【cue】不参与对齐，读到时短暂显示。** 括号里的舞台提示不要求念出来，到达时短暂显示，然后自动越过。
   依据：VoiceScroll 的 `[smiling]` 会被跟踪跳过并短暂显示【已核实】；Teleprompter for Video 跳过 `<speaker 1>`【已核实】；Textream issue #31 中用户抱怨 cue 必须照读，否则就落后【已核实-issue】；MeyerPro 建议 cue 单独起行并用操作员颜色【已核实】。
5. **为中文和中英混排的分词写回归测试。**
   Textream 中文跟随失效的根因是“中文无空格，整段被当作一个词，前缀匹配直接跳到段尾”（issue #60）。另一个 bug 是全角标点被当作注释渲染，同一行里的半角数字或英文词被截成“…”（issue #128）。两条均【已核实-issue】。
   另外，VoiceScroll 1.9.2 修复了“念出的数字和稿面阿拉伯数字对不上”的问题【已核实-更新日志】。中文口播里常见“36 岁”被念成“三十六岁”，拼音对齐需要做数字到读音的归一化。
6. **保证长时间识别不中断。** Apple 文档说明 `SFSpeechRecognizer` 会终止超过一分钟的识别任务【已核实-文档镜像】。Textream 出现过“每约 58 秒冻结一次”的问题（issue #55，已修复）【已核实】。
   NotchCue 需要做无缝的任务轮换（新旧任务重叠、状态续接），或者在 macOS 26 上改用 `SpeechAnalyzer`。WWDC25 称它面向长语音【已核实】，但它的时长上限查不到官方说明。
7. **提供灵敏度和噪声门槛、悬停暂停、开场倒计时和分段跳转。**
   依据：Elgato Voice Sync 2.0 新增了 sensitivity 滑块【已核实】；Moody 官方承认背景噪声会被当成说话，建议调麦克风灵敏度或戴耳机【已核实】；Notchie 和 Moody 都支持鼠标悬停暂停【已核实】；Moody Cue 可分段跳转，Avocado 用 `#` 标题分段并显示按你的语速何时会到达该段【已核实】；Teleprompter.com 提供倒计时、剩余时间和进度条【已核实】。

---

## 竞品对比表

“查不到”表示官方渠道没有找到说明。

| 产品 | 平台 | 显示方式 | 当前位置怎么标示 | 滚动方式 | 语音跟随 & 中文支持 | 值得借鉴 | 来源 |
|---|---|---|---|---|---|---|---|
| **PromptSmart+ / Pro**（VoiceTrack） | iOS、Android、Mac | 镜像、窄边距、按词着色、粗体/斜体；可放在前置摄像头旁 | 查不到具体样式 | 语音跟随，暂停或即兴时停住，回到稿子后继续；也有匀速模式 | 设备端识别，可离线。PromptSmart+ 列出 15 种语言，含普通话【已核实】；官网 how-it-works 页面只列 5 种，旧版 Pro 只支持英文，各渠道说法不一致 | waypoint 加快捷键跳转；Web 遥控室 | [App Store](https://apps.apple.com/us/app/promptsmart/id1526733375)、[how-it-works](https://promptsmart.com/how-it-works) |
| **Teleprompter.com**（VoiceGlide） | iOS、Android、Mac、Web | 字体可选（含 Lexend、OpenDyslexic）、边距可调、镜像、倒计时、剩余时间、进度条 | **Cue Indicator**：正在说的词钉在固定行；关闭平滑滚动时，当前词会跳到屏幕顶部 | 语音跟随，可开关平滑滚动 | 设备端识别，可离线；28 种语言，含简体和繁体中文【已核实】；语音命令按稿件语言识别 | “Go current” 语音找回位置；可用遥控设备的麦克风收音 | [功能页](https://www.teleprompter.com/features/voice-scrolling)、[App Store](https://apps.apple.com/us/app/teleprompter-com/id1420515755) |
| **Speakflow**（Flow 模式） | 浏览器 | 查不到 | 官方说法是“把每个词滚动进视野” | Flow / Auto / Manual 三种；静默 30 秒自动停止收听 | 免费演示的语音控制需要 Chrome 或 Edge；语言列表查不到 | 静默超时自动停止 | [文档](https://www.speakflow.com/docs/scroll-modes-flow-auto) |
| **BIGVU** | iOS、Android、Web | 可调速度、文字位置 | 查不到 | 匀速，检测到停顿时暂停【已核实-官方营销页】；第三方称它只检测声音、不识别词 | 宣称“多语言”，但具体语言查不到 | AI 眼神矫正（有单独教程）、字幕 | [移动端页](https://bigvu.tv/tools/teleprompter-mobile-teleprompter-ios-android/)、[教程](https://bigvu.tv/tutorials/teleprompter/) |
| **Elgato Camera Hub → Studio 2.0**（Voice Sync） | Win、Mac（配合硬件提词器） | 字体和字号可调，间距可调；编辑器支持标题、列表 | **已读变暗**，加 reading position 滑块 | 只在说话时滚动 | 2.0 版仅支持英文，德语在计划中【已核实】；旧版要求 RTX 2060 或 Apple Silicon | 灵敏度滑块，适合常即兴的人 | [Studio 2.0](https://www.elgato.com/us/en/explorer/products/teleprompter/elgato-studio-2-0-the-prompter-experience-rebuilt/) |
| **Teleprompter Pro** | iOS、Mac | 富文本（粗体、斜体、下划线、颜色）、镜像、外接显示 | **箭头或线形 cue indicator**，样式、颜色、位置、透明度均可调 | 手动或定时 | 未发现语音跟随 | 剩余时间时钟；踏板和遥控支持 | [features](https://teleprompterpro.com/features) |
| **Teleprompter for Video** | iOS、Android | 查不到 | 查不到（波形只反映音量） | 语音模式，录制开始后才滚动 | iOS 50+ 种语言，Android 10 种；有在线和离线两种模式，离线精度较低；中文是否在列查不到 | `<...>` 内文字被跳过 | [支持页](https://teleprompterforvideo.com/support/voice-activated-teleprompter-app) |
| **VoiceScroll** | iOS | 阅读框可拖到镜头高度，宽度可调 | **当前词填色（橙色）或下划线，已读变灰**，未读保持白色 | 语音跟随，可选“快速响应”或“高精度”（iOS 26） | 33–34 种语言，含简体、繁体、粤语【已核实】；评分 3.3/5（12 个评分） | `[方括号]` 跳过并短暂显示；数字读音与阿拉伯数字匹配 | [App Store](https://apps.apple.com/us/app/voicescroll-teleprompter/id6760583162) |
| **剪映 / CapCut 提词器** | 移动端 | 可调字号、颜色、速度，窗口可移动 | 查不到 | 匀速，点击暂停 | **未找到官方语音跟随说明**；第三方文章明确说 CapCut 不支持【第三方】 | 录制时长预设 | [MakeUseOf](https://www.makeuseof.com/capcut-how-to-use-teleprompter/)、[脚本之家](https://www.jb51.net/softjc/837952.html) |
| **爱提词** | iOS、Android | 有悬浮提词，可盖在任意 App 上 | 查不到 | AI 提词或匀速 | 官方称“无论语速变化还是加词跳词，都能灵活适应”【已核实-App Store】；有用户说不支持英文、需要联网【坊间】 | 早期国内“AI 跟随”的代表产品 | [App Store CN](https://apps.apple.com/cn/app/%E7%88%B1%E6%8F%90%E8%AF%8D-%E5%8F%A3%E6%92%AD%E7%9F%AD%E8%A7%86%E9%A2%91%E7%9B%B4%E6%92%AD%E6%8B%8D%E6%91%84%E5%8A%A9%E6%89%8B/id6449637608) |
| **灵感提词器** | iOS | 字号、行距、颜色、28 种背景、倒计时；口播和普通模式分别保存设置 | 有“高亮推进”；3.6 版让已读/未读区分更清楚 | 语音跟随，停下时等待 | 3.6.5 版称跳句或漏读后能“更自然地接着跟读”；识别语言查不到 | 两种模式分别保存设置 | [App Store](https://apps.apple.com/us/app/%E7%81%B5%E6%84%9F%E6%8F%90%E8%AF%8D%E5%99%A8-ai%E5%8F%A3%E6%92%AD%E8%AF%AD%E9%9F%B3%E8%B7%9F%E9%9A%8F/id6749378913?l=zh-Hans-CN) |
| **轻抖** | iOS、Android、PC | 悬浮提词，速度、大小、透明度可调 | 查不到 | 匀速或 AI 跟随 | 官方说法“你语速快它就快，你停它就停”；第三方称支持普通话、粤语、英文【第三方】 | 价格高（手机年卡 ¥388） | [应用宝](https://sj.qq.com/appdetail/com.qingdou.android)、[App Store CN](https://apps.apple.com/cn/app/%E8%BD%BB%E6%8A%96/id1559475886) |
| **提词全能王** | Android 等 | 悬浮窗、透明度、镜像 | 查不到 | 官方描述是“内置 AI 分析语速”，更像按语速调节，不是按内容定位 | 查不到 | 无 | [应用宝](https://sj.qq.com/appdetail/com.dongqi.teleprompter) |
| **Notchie** | Mac（刘海） | 宽、高、透明度可调；深浅色模式 | 查不到 | “你说它就滚，你停它就停” | 只列出英文；VoicePrompter 博客称它只做声音检测，即兴时会丢位【第三方-竞品作者】 | 悬停暂停；脚本队列；共享屏幕时隐藏 | [App Store](https://apps.apple.com/us/app/notchie/id6756745307?mt=12) |
| **NotchPrompter** | Mac | 字号、字体（含 OpenDyslexic）、深浅色；可放在刘海、角落或浮窗 | 查不到 | 有声即滚，静音即停 | 查不到；开源免费，App Store 版为一次性付费 | 开源，可读代码 | [官网](https://notchprompter.com/)、[GitHub](https://github.com/jpomykala/NotchPrompter/) |
| **Moody** | Mac | 窗口和字号可调；有随音量变化的光束 | 查不到 | 语音跟随，可手动或用快捷键调节；悬停暂停 | 语言查不到；官方承认噪声会误触发 | Moody Cue 分段跳转；开场倒计时；iPhone 遥控；$39 买断 | [官网](https://moody.mjarosz.com/) |
| **Textream**（开源） | Mac、iOS | 14/16/20/24 pt 四档；刘海宽 280–500 px；玻璃材质 0–60% 透明度 | **逐词高亮**（6 种颜色）；活动行在摄像头正下方 | 三种模式：词跟踪、匀速、有声滚动 | 可选识别语言；**CJK 跟踪失效**（issue #60）、全角标点问题（#128）、约 58 秒冻结（#55，已修）【已核实】 | 点词跳转；`[方括号]` cue 单独着色；Director 模式 | [GitHub](https://github.com/f/textream)、[#60](https://github.com/f/textream/issues/60)、[#128](https://github.com/f/textream/issues/128) |
| **Avocado** | Mac、iOS | 字号 16–72 pt，默认 24；刘海宽 300–800 pt；行距 0–24 pt | 有 “Focus Guide”，具体样式查不到 | 匀速 50–300 WPM，或语音自适应（会学习你的语速） | 语言查不到 | `#` 分段，并显示按你的语速何时到达 | [官网](https://avocadonotch.com/)、[字号博客](https://avocadonotch.com/blog/teleprompter-font-size) |

**没有核实的产品：** Descript 未找到可核实的提词器或语音跟随功能，已跳过。秒剪未找到提词器功能。名为 “Teleprompter Premium” 的 App 查不到，Teleprompter.com 官网特别声明自己与它无关。CueNotch 只查到它自家的对比博客，没有纳入。

---

## 英文显示专项

### 业界建议

| 维度 | 建议 | 来源 |
|---|---|---|
| 每行词数 | **5–8 词** | Avocado【已核实-厂商博客】 |
| | 8–10 词，避免用连字符断行 | MeyerPro【已核实-行业博客】 |
| | 3–4 词（大号全大写字体时） | Creative COW 论坛【坊间】 |
| 每行字符 | 广播稿 30–40 字符；用口语节奏的短句断行，而不是按书面语法 | teleprompter.works【第三方，作者是竞品】 |
| | 字幕 42 字符/行；一行能放下就不拆；拆成两行时上短下长；不要让一两个词单独占一行 | Netflix【已核实】 |
| 大小写 | **用句首大写（sentence case），不用全大写**。全大写阅读更慢（Tinker & Paterson 可读性研究），而且更占宽度 | Avocado、MeyerPro【已核实】 |
| | 全大写是旧广播的传统，部分主播仍然偏好 | 多个博客【第三方】 |
| | 全大写只留给 [PAUSE]、[APPLAUSE] 这类 cue | MeyerPro |
| 字体 | 无衬线：SF Pro、Helvetica Neue、Avenir Next；避免等宽字体，因为每行装的词更少 | Avocado |
| | 全稿只用一种字体，粗体少用 | MeyerPro |
| 字号 | MacBook 近距离（50 cm）约 26 pt；一臂距离（60 cm）约 30 pt | Avocado |
| | 如果一行只装得下 2–3 个词，说明字号太大 | Avocado |
| 行距与可视行数 | 行距接近正常段落间距，段与段之间空一行；可视行数没有找到统一建议 | Avocado、MeyerPro |
| 语速 | 口播或镜头前 **130–160 wpm**；高管讲话 120–150；新闻主播 150–180 | MeyerPro【已核实】、teleprompter.works 等【第三方】 |
| 视线角度 | 视线向下偏到约 5° 以内，观众仍觉得在对视；左右偏移只能容忍约 1°（Chen, CHI 2002） | Avocado 引用【已核实-二手引用】 |

### NotchCue 英文模式建议参数【推断】

**为什么现在显得字少。** 22 pt 的 SF Pro 下，一个汉字宽约 22 pt，13 字约 286 pt。英文小写加空格的平均字宽约 0.5–0.55 em，也就是 11–12 pt。286 pt 只能放约 24–26 个字符，相当于 4–5 个词，低于业界下限的 5 个词。

**换行节奏也对不上。**

| 语言 | 每行内容 | 语速 | 每行停留 |
|---|---|---|---|
| 中文 | 14 字 | 250 字/分 | 约 3.4 秒 |
| 英文 | 4.5 词 | 150 wpm | 约 1.8 秒 |

英文换行和滚动的频率接近中文的两倍，读起来会觉得“碎”。要让英文每行也停留约 3 秒，每行需要放约 7–8 个词。

**换算比例。** Netflix 的字号设定是：英文 42 字符铺满画面，中文 16 字铺满画面。相同物理宽度下，比例约为 1 汉字 : 2.6 拉丁字符。按这个比例，13 汉字宽的卡片对应约 34 个拉丁字符，约 6 个词。这说明在同宽卡片上，英文字号可以略小于中文，看起来仍然协调；拉丁字母的 x-height 本来就比汉字的字面小。

**建议参数如下。**

1. **卡片宽度改用 pt 定义，同时显示“约 N 字 / 约 N 词”。** 不要再用“汉字数”作为唯一单位。
2. **英文默认值：** 字号 22 pt（可选 20 pt），每行目标 **36–42 字符，约 6–8 词**，卡片宽约 **400–450 pt**。在 14 英寸 MacBook Pro 上，1 pt 约等于 0.2 mm，450 pt 约 9 cm。50 cm 视距下，左右总扫视约 10°，和 Avocado 给出的“刘海提词器 8 cm、约 8°”在同一量级。中文默认值仍是约 300–330 pt。
3. **英文行数：** 默认 2 行。英文单行信息量低，2 行可以减少视线来回追行。
4. **按意群断行，不要把行填满。** 优先在标点、连词或介词前断行；不要让一个词单独占一行；不要用连字符断词。另外做行宽均衡：两行时上短下长。依据是 Netflix 的拆行规则和广播稿“按口语节奏断句”的做法。
5. **大小写：** 默认保持原文的大小写，不提供“强制全大写”作为默认。【cue】可以用小型大写字母或其他颜色来区分。
6. **当前位置：** 英文高亮当前词加下一个词，比只高亮下一个词更利于预读；已读部分变暗。
7. **默认语速：** 匀速模式默认 140 wpm（可调 120–180），中文默认 250 字/分。可以按稿件的主要语言自动切换。

**中英文是否应该用不同默认值：应该。** 至少宽度、行数、语速单位（wpm 和字/分）、高亮粒度这几项要分开。可以按稿件里拉丁字母和汉字的比例自动判断语言；中英混排时，按实际渲染宽度断行。

---

## 中文显示专项

### 资料

| 维度 | 建议 | 来源 |
|---|---|---|
| 每行字数 | 字幕 **16 字/行**，必要时到 18；最多两行；一行能放下就不拆；上短下长 | Netflix 简中规范【已核实】 |
| | 提词“一行十个字上下不容易串行”；行距 1.5 倍以上 | 博客园文章【第三方，非权威】 |
| 可视行数 | 手机口播单屏 5–6 行；文字区越窄，眼球左右移动越少；电脑直播用半透明悬浮窗，放在摄像头正下方；倒计时约 3 秒 | 博客园文章【第三方】 |
| 标点 | 字幕规范是用空格代替逗号和句号；数字用半角；不要阿拉伯数字和汉字混写（如“五千2百”） | Netflix【已核实】 |
| | 提词稿不一定要照搬“去标点”这条，但半角数字、避免混写的规则可以借鉴 | 【推断】 |
| 语速 | 普通话朗读约 240 音节/分；广播新闻 250–270 字/分；听辨上限约每秒 4–5 字 | 百度百科等【第三方，可追溯性一般】 |
| | 自然口播 150–180 字/分 | CSDN 提词器指南【第三方】 |
| | 1 分钟口播脚本不超过 300 字 | 人人都是产品经理【第三方】 |
| | 以上数字差距很大，可信度都一般 | 【综合判断】 |

### NotchCue 中文模式建议【推断】

- **每行字数：** 默认每行 **14 字**（可调 12–16）。12 字偏少，手动选 16 字也合理，等同 Netflix 的上限。字号 22 pt 保持不变。
- **行数：** 默认 2 行，可选 3 行。中文单行信息密度高，1 行也能用，但不利于预读。
- **断行规则：**
  - 做避头尾处理：“，。！？、；：”和右引号、右括号不出现在行首。
  - 数字串和英文词不拆开。这是 Textream #128 踩过的坑。
  - 优先在标点处断行。
  - 全角标点要算进宽度，但不要作为独立的“词”进入对齐。
- **默认语速：** 匀速模式默认 **240 字/分**（可调 150–320）。拼音对齐时要把“36”和“三十六”这类写法归一化。
- **高亮：** 当前 2 字高亮、已读变暗的做法保留。中文也可以改为“当前词”高亮，需要先分词。

---

## 用户常见抱怨清单（我们可以超越的点）

| # | 抱怨 | 涉及产品 | 来源与可靠性 |
|---|---|---|---|
| 1 | 跳到很前面去，或者突然不跟了；“读着读着跳过一两页” | PromptSmart Pro | [App Store 评论](https://apps.apple.com/us/app/promptsmart-pro-teleprompter/id894811756?see-all=reviews&platform=ipad)【坊间，多条，跨越多年】 |
| 2 | 稿子里有重复短语时，会跳到后面那一处 | PromptSmart Pro | 搜索摘要中的 App Store 评论【坊间，没有逐字核对原文】 |
| 3 | 跑题后只有约 80% 的情况能追回来 | PromptSmart+ | [App Store 评论](https://apps.apple.com/us/app/promptsmart/id1526733375)【坊间】；另有一篇评测给出“安静环境下约 80% 的 take 准确”，但作者是竞品方 |
| 4 | 噪声或远距离收音时失灵；噪声被当成说话 | PromptSmart、Moody | PromptSmart 开发者回复、Moody 官网【已核实-官方承认】 |
| 5 | 词跟踪表现得像“有声就滚”；重复一句后无法拖回去 | Textream | [issue #22](https://github.com/f/textream/issues/22)【已核实-issue，多人 +1】 |
| 6 | 一个词没识别出来就卡住，即使后面的词都识别对了；前瞻窗口只有约 5–6 个词 | Textream | [issue #46](https://github.com/f/textream/issues/46)【已核实-issue】 |
| 7 | cue 也要照读，否则越来越落后，偶尔冻结 | Textream | [issue #31](https://github.com/f/textream/issues/31)【已核实-issue】 |
| 8 | 中日韩文本的跟踪完全失效（直接跳到段尾）；全角标点和数字显示异常；无法输入中文 | Textream | [#60](https://github.com/f/textream/issues/60)、[#128](https://github.com/f/textream/issues/128)、#34、#95【已核实-issue】 |
| 9 | 每约 58 秒冻结一次，需要手动重启 | Textream | [issue #55](https://github.com/f/textream/issues/55)（已修复）【已核实】 |
| 10 | 调整窗口大小后跟踪失效；跟踪时手动滚动或点击跳转不稳定；反向滚动时画面抖动 | Textream | issue #48、#71、#88【已核实-issue 标题】 |
| 11 | 在 macOS Tahoe 26 上“几乎不能用”；回车不换行，文字跑出右边；开播时显示占位文字 | Notchie | [App Store 评论](https://apps.apple.com/us/app/notchie/id6756745307?mt=12)【坊间，单条】 |
| 12 | 一上台就检测不到声音，又不能手动滚动 | 爱提词 | App Store CN 评论（2023-06-21）【坊间，单条，开发者已回复】 |
| 13 | iPad 上提示“语音识别未就绪” | VoiceScroll | App Store 评论【坊间】；开发者解释是需要先下载设备端模型 |
| 14 | 只有英文可用，或者在非英文语言下明显变差 | Elgato（仅英文）、PromptSmart Pro 旧版 | Elgato 官方【已核实】；PromptSmart 部分【第三方】 |
| 15 | 订阅价格高、扣费出乎意料 | PromptSmart、Teleprompter.com、轻抖 | 各家 App Store 评论和价格表【坊间加已核实价格】 |

**对 NotchCue 的含义【推断】：**

- 第 1、2、5、6 条说明两件事：一是需要“全局重定位加局部平滑”的双层对齐；二是遇到重复短语时，优先选离当前位置近的候选，而不是第一个匹配。
- 第 7、8、9 条是低成本、高收益的工程细节，见“最该借鉴的 7 件事”第 4–6 条。
- 第 4 条说明需要灵敏度设置或噪声门槛，并在状态岛上清楚显示“正在听到你”。我们已有波形显示，可以再加一个“未匹配到稿子”的状态色。

---

## 已核实与推断的边界

- **【已核实】** 各产品官网、App Store 页面、Elgato 官方文章、Netflix 规范、Textream README 和 issue 中的具体数字与功能。
- **【第三方】** VoicePrompter 博客（作者自己做竞品 App）、teleprompter.works（竞品站）、CueNotch 博客（竞品）、各中文下载站和博客。这些可以当线索，不宜当定论。
- **【推断】** 字宽换算、每行停留时间、物理宽度和视角计算、NotchCue 各项参数建议。上线前建议用真实的英文和中文口播稿各录 3 条做 A/B，验证 6–8 词/行和 14 字/行这两个默认值。
- **查不到：** Speakflow 和 BIGVU 支持的识别语言；剪映、轻抖、提词全能王的当前位置标示方式和识别原理；Descript 的提词功能；`SpeechAnalyzer` 的官方时长上限。
