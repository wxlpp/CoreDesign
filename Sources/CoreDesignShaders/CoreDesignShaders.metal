//
//  CoreDesignShaders.metal
//  CoreDesignShaders
//
//  全部 `[[stitchable]]` 入口 + 共用的噪声原语。
//
//  ⚠️ **为什么所有 shader 在同一个文件里**：Metal 的 helper 函数跨 `.metal` 文件复用
//  需要头文件声明，而 SwiftPM 的资源处理对 `.h` 的支持不明确。噪声原语确实是多个
//  shader 共用的，放同一编译单元既避开该不确定性、又不需要重复实现。
//  各入口之间用 `// MARK: -` 分节，与本仓 Swift 侧的分节惯例一致。
//
//  ⚠️ **本文件零硬编码色**（FR-8）。所有颜色由 Swift 侧经 `.color(...)` 传入——
//  这既是色彩纪律，也是「自研实现」差异化的一条（见 `docs/shader-provenance.md`）。
//
//  ⚠️ **不要为了"更像某个参考效果"去增补参数**——那会把形参面推向上游的 uniform 列表，
//  正是 provenance 表用来指认来源的那条链。
//

#include <metal_stdlib>
// ⚠️ **`layerEffect` 用到的 `SwiftUI::Layer` 需要这个 include**，否则
// `error: use of undeclared identifier 'SwiftUI'`。只写 `<metal_stdlib>` 不够。
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - 共用原语 / Shared primitives

namespace cd {

// ⚠️ **本节的原语是重写过的，不是第一版**（#261 终审 C-1）。
//
// 第一版用的是 `fract(p * float2(123.34, 456.21)); p += dot(p, p + 45.32)` 那组常量
// ——它与 ShipSwift 的 `swInkSmokeHash21` / `swLiquidChromeHash` / `swHt_hash21`
// **逐字节相同**，而那组常量出自 The Art of Code 的 Shadertoy 教程（Shadertoy 默认许可
// CC BY-NC-SA）。
//
// ⇒ 本 PR 曾声称的「下一个 reviewer 用形参比对反查会落空」**是假的**：只要多做一步
// `grep 123.34` 就命中。**形参不匹配不证明函数体独立**——函数体才是受保护的表达。
//
// ⚠️⚠️ **第二版（改用位运算整数 hash）重蹈了同一失败模式，只是换了被复制的对象**
//（PR #261 第 2 轮终审 C-1）。第二版的注释写「Wang hash 家族的**公开构造**」——
// 那正是 #249 裁定明令不接受的「provenance 未知」型**否定断言**，裁定要求正向拿到
// 三种判决之一。按本文件自己上面那条判据复核第二版：
//   · `grep 0x27d4eb2d`  → 命中 **Thomas Wang** 整数 hash，经 **Nathan Reed**
//     《Quick And Easy GPU Random Numbers In D3D11》(2013) 传播的 GPU 版本，逐字符一致；
//   · `grep 73856093`    → 命中 **Teschner et al. 2003**《Optimized Spatial Hashing for
//     Collision Detection of Deformable Objects》的素数三元组
//     `73856093 / 19349663 / 83492791`。
//
// ⇒ **本版不再声称原创，改为正向署名**。这两项都是**公开发表的算法与常数**
//（Wang 的页面无许可声明；Teschner 是论文里的数字），法律风险低于 Shadertoy 的
// CC BY-NC-SA——但**低风险 ≠ 已裁定**，本仓的门是正向裁定，故逐项写明出处。
// 逐项条目须随 `docs/shader-provenance.md`（task #249）落地，见本文件末尾的合入前置。

/// 32-bit 整数雪崩混合。
///
/// ⚠️ **出处：Thomas Wang 的整数 hash，GPU 版本经 Nathan Reed (2013) 传播。**
/// 逐字符一致，**不是本仓原创**。常数 `0x27d4eb2d` 是它的指纹。
inline uint wangHash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16);
    seed *= 9u;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15);
    return seed;
}

/// 二维格点 → [0, 1)。两个整数坐标先线性组合成一个 seed，再走整数雪崩。
///
/// ⚠️ **出处：素数三元组 `73856093 / 19349663 / 83492791` 出自 Teschner et al. 2003**
///《Optimized Spatial Hashing for Collision Detection of Deformable Objects》，
/// 是图形代码里最好 grep 的常量之一，**不是本仓原创**。
///
/// ⚠️ **先转 `uint` 再乘不是风格问题**（终审 I-2）：`int × int` 在
/// `DotGrid.Spacing.tight`（spacing 30）与 `Starfield.Density.dense`（cells 38）
/// 乘上竖屏 aspect ≈ 2.16 后，格点索引到 65–82，`82 × 83492791 ≈ 6.8e9 > INT_MAX`
/// ⇒ **默认档位就有符号溢出**。MSL 继承 C++ 语义，有符号溢出是 **UB**——
/// 今天在 Apple GPU 上回绕、看着照样随机，但编译器有权按「不会溢出」优化。
/// 无符号回绕是良定义的。
///
/// ⚠️ **偏移必须取整数**（终审 S-2）：本函数内部先 `floor(p)`，
/// 故 `hash21(cell + 7.13)` 与 `hash21(cell + 7.0)` **完全等价**，小数部分是死值。
inline float hash21(float2 p) {
    uint2 i = uint2(int2(floor(p)));
    uint seed = (i.x * 73856093u) ^ (i.y * 19349663u);
    return float(wangHash(seed) & 0x00FFFFFFu) / float(0x01000000u);
}

/// 二维 hash → float2。第二个分量用不同的 seed 扰动，避免两轴相关。
inline float2 hash22(float2 p) {
    uint2 i = uint2(int2(floor(p)));
    uint sx = (i.x * 73856093u) ^ (i.y * 19349663u);
    // ⚠️ `50331653` 不属 Teschner 三元组，是标准哈希表素数表里的条目（第 3 轮终审 S）。
    uint sy = (i.x * 83492791u) ^ (i.y * 50331653u);
    return float2(float(wangHash(sx) & 0x00FFFFFFu),
                  float(wangHash(sy) & 0x00FFFFFFu)) / float(0x01000000u);
}

/// 值噪声：四角 hash 双线性插值。
///
/// ⚠️ 双线性插值 + `smoothstep` 权重是值噪声的**定义**（教科书）。
/// ⚠️ **初版这里写「不存在『另一种写法』」——那是一句可证伪的否定式 provenance 断言**
///（第 3 轮终审 I-2），正是本文件自己判定不接受的那一类。至少有两种在野的标准形态：
/// 嵌套 `mix(mix(a,b,u.x), mix(c,d,u.x), u.y)`（**本文件采用**，与 iq 的写法一致）
/// 与 The Book of Shaders 的展开式 `mix(a,b,u.x) + (c-a)*u.y*(1-u.x) + (d-b)*u.x*u.y`。
/// 两者等价，本文件选了前者；
/// 可替换的是**底下的 hash**，那一层已按上面的说明重写。
inline float valueNoise(float2 p) {
    float2 cell = floor(p);
    float2 frac = fract(p);
    float2 weight = frac * frac * (3.0 - 2.0 * frac);

    float c00 = hash21(cell);
    float c10 = hash21(cell + float2(1.0, 0.0));
    float c01 = hash21(cell + float2(0.0, 1.0));
    float c11 = hash21(cell + float2(1.0, 1.0));

    return mix(mix(c00, c10, weight.x), mix(c01, c11, weight.x), weight.y);
}

/// FBM：频率翻倍、幅度减半，归一化到 [0, 1]。
inline float fbm(float2 p, int octaves) {
    float sum = 0.0;
    float amplitude = 0.5;
    float total = 0.0;
    for (int i = 0; i < octaves; ++i) {
        sum += valueNoise(p) * amplitude;
        total += amplitude;
        p *= 2.0;
        amplitude *= 0.5;
    }
    return sum / max(total, 1e-4);
}

/// 三档调色斜坡：`v ∈ [0,1]` → low → mid → high，接缝用 smoothstep 抹平。
inline half4 ramp3(float v, half4 low, half4 mid, half4 high) {
    half4 lower = mix(low, mid, half(smoothstep(0.0, 0.5, v)));
    half4 upper = mix(mid, high, half(smoothstep(0.5, 1.0, v)));
    return mix(lower, upper, half(step(0.5, v)));
}

/// 抗锯齿边宽。⚠️ **必须经此取，不要直接用 `fwidth`**：平坦区域 `fwidth` 可为 0，
/// 会让 `smoothstep(x - 0, x + 0, …)` 变成 0/0 → NaN（#261 终审 I-5）。
inline float edgeWidth(float x) {
    return max(fwidth(x), 1e-4);
}

} // namespace cd

// MARK: - Plasma

/// 四相正弦叠加。经典配方：两个轴向波 + 一个对角波 + 一个径向波。
[[stitchable]] half4 coreDesignPlasma(float2 position, half4 currentColor,
                                      float2 size, float time,
                                      float frequency, float octaves,
                                      half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float value = 0.0, amplitude = 1.0, total = 0.0, f = frequency;

    for (int i = 0; i < int(octaves); ++i) {
        float2 p = uv * f;
        float axial = sin(p.x + time) + sin(p.y + time * 1.13);
        float diagonal = sin((p.x + p.y) * 0.5 + time * 0.87);
        float radial = sin(length(p - f * 0.5) + time * 1.31);
        value += (axial + diagonal + radial) * 0.25 * amplitude;
        total += amplitude;
        amplitude *= 0.5;
        f *= 2.0;
    }
    return cd::ramp3(saturate(value / max(total, 1e-4) * 0.5 + 0.5), low, mid, high);
}

// MARK: - Starfield

/// 网格分格，每格随机放一颗星；亮度按到星心的距离衰减，闪烁由每星独立相位驱动。
[[stitchable]] half4 coreDesignStarfield(float2 position, half4 currentColor,
                                         float2 size, float time,
                                         float density, float twinkle,
                                         half4 sky, half4 star) {
    float2 uv = position / max(size, float2(1.0));
    float aspect = max(size.x, 1.0) / max(size.y, 1.0);
    float2 grid = float2(density * aspect, density);
    float2 cell = floor(uv * grid);
    float2 local = fract(uv * grid) - 0.5;

    float2 jitter = cd::hash22(cell) - 0.5;
    float brightness = cd::hash21(cell + 7.13);

    // 只有一部分格子有星：亮度低于门限的直接熄灭，避免规则网格感。
    float alive = step(0.55, brightness);
    float d = length(local - jitter * 0.7);
    float glow = alive * smoothstep(0.16, 0.0, d) * brightness;

    // 每颗星独立相位，`twinkle` 控制振幅（0 = 不闪）。
    float phase = brightness * 6.2831853;
    glow *= 1.0 - twinkle * 0.5 * (1.0 - sin(time * 2.0 + phase));

    return mix(sky, star, half(saturate(glow)));
}

// MARK: - DotGrid

/// 规则点阵。`spacing` 决定格数，`radius` 决定点的相对半径，
/// `pulse` 让点按到中心的距离做呼吸（0 = 完全静态）。
[[stitchable]] half4 coreDesignDotGrid(float2 position, half4 currentColor,
                                       float2 size, float time,
                                       float spacing, float radius, float pulse,
                                       half4 background, half4 dotColor) {
    float2 s = max(size, float2(1.0));
    float2 uv = position / s;
    float aspect = s.x / s.y;
    float2 grid = float2(spacing * aspect, spacing);

    float2 cell = floor(uv * grid);
    float2 local = fract(uv * grid) - 0.5;

    // 呼吸：以画面中心为源的同心波，相位随格子到中心的距离推进。
    float2 centred = (cell + 0.5) / grid - 0.5;
    float wave = sin(length(centred) * 12.0 - time * 2.0) * 0.5 + 0.5;
    float r = radius * (1.0 - pulse + pulse * wave);

    // 抗锯齿边：用屏幕空间导数推边宽，避免固定值在不同分辨率下粗细不一。
    float d = length(local);
    float edge = cd::edgeWidth(d) * 1.5;
    float mask = 1.0 - smoothstep(r - edge, r + edge, d);

    return mix(background, dotColor, half(saturate(mask)));
}

// MARK: - FractalClouds

/// FBM 云层。两次域扭曲：先用一层 FBM 扰动采样坐标，再对扰动后的坐标取 FBM。
[[stitchable]] half4 coreDesignFractalClouds(float2 position, half4 currentColor,
                                             float2 size, float time,
                                             float scale, float octaves, float warp,
                                             half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;
    p.x += time * 0.35;

    // ⚠️ 偏移常量是本仓自定的（3.11 / 6.47），**不是** iq domain-warping 文章那组
    // `(1.7, 9.2) / (8.3, 2.8)`——第一版沿用了那组，见本文件头的说明。
    float2 offset = float2(cd::fbm(p + 3.11, int(octaves)),
                           cd::fbm(p + 6.47, int(octaves)));
    float v = cd::fbm(p + warp * (offset - 0.5), int(octaves));

    return cd::ramp3(saturate(v), low, mid, high);
}

// MARK: - InkSmoke

/// 墨烟：比 `FractalClouds` 更强的域扭曲 + 更陡的对比，形成丝缕感而非团块感。
[[stitchable]] half4 coreDesignInkSmoke(float2 position, half4 currentColor,
                                        float2 size, float time,
                                        float scale, float octaves, float wisp,
                                        half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;
    p.y -= time * 0.5;   // 烟向上飘

    // 两级域扭曲：第二级用第一级的结果再扰动一次，丝缕由此而来。
    //
    // ⚠️⚠️ **本段的结构派生自 Inigo Quilez《Domain Warping》一文的公开片段**
    //（终审 C-2）。原文：`vec2 q = vec2(fbm(p+(0,0)), fbm(p+(5.2,1.3)));`
    // `vec2 r = vec2(fbm(p+4*q+(1.7,9.2)), fbm(p+4*q+(8.3,2.8))); return fbm(p+4*r);`
    // 与下面三行**一一对应**：同样的三级级联、同样的 `p + k*q + offset` 形状，
    // **连变量名 `q` / `r` 都保留**。差别只是把 `4.0` 参数化成 `wisp`、把 vec2 偏移
    // 换成标量。
    // ⇒ 初版注释「偏移常量本仓自定，不沿用 iq 那组」**说的是实话，但不构成独立**
    //   ——本文件上面已写死「改常量不构成独立」。本版不再声称原创。
    // ⚠️ 同一问题的弱化版在 `coreDesignFractalClouds`（单级 warp，指纹较弱）。
    float2 q = float2(cd::fbm(p, int(octaves)), cd::fbm(p + 2.73, int(octaves)));
    float2 r = float2(cd::fbm(p + wisp * q + 4.19, int(octaves)),
                      cd::fbm(p + wisp * q + 7.61, int(octaves)));
    float v = cd::fbm(p + wisp * r, int(octaves));

    // 陡对比：把中段拉开，两端压平，读起来像烟而不像云。
    v = smoothstep(0.28, 0.72, v);
    return cd::ramp3(saturate(v), low, mid, high);
}

// MARK: - LiquidChrome

/// 液态铬：域扭曲后的坐标喂给正弦带，带边用 `fwidth` 抗锯齿，
/// 形成金属反射那种"窄而亮的高光带 + 宽而暗的过渡"。
[[stitchable]] half4 coreDesignLiquidChrome(float2 position, half4 currentColor,
                                            float2 size, float time,
                                            float scale, float bands, float flow,
                                            half4 low, half4 mid, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = uv * scale;

    float2 warp = float2(cd::fbm(p + time * 0.15, 3),
                         cd::fbm(p + 5.83 - time * 0.11, 3)) - 0.5;
    float2 q = p + flow * warp;

    // 正弦带 → [0,1]，再用导数做边缘抗锯齿，避免高频带出现摩尔纹。
    float raw = sin((q.x + q.y) * bands) * 0.5 + 0.5;
    float aa = cd::edgeWidth(raw);
    float v = smoothstep(0.5 - aa, 0.5 + aa, raw);

    // 金属感：把带边处的亮度再抬一档，模拟高光收窄。
    float sheen = pow(saturate(1.0 - abs(raw - 0.5) * 2.0), 3.0);
    return cd::ramp3(saturate(v * 0.75 + sheen * 0.25), low, mid, high);
}

// MARK: - RefractiveGlass（layerEffect）

namespace cd {

/// 圆角矩形 SDF：内部为负、外部为正、边界为 0。
///
/// ⚠️ 这是圆角矩形 SDF 的**标准闭式解**，无第二种写法（`length(max(q,0)) + min(max(q.x,q.y),0) - r`）。
/// 公开出处为 Inigo Quilez 的 2D distance functions 文章——⚠️ **该页无许可声明**
/// （`docs/shader-provenance.md` §C #24 已就此把 `Glass` 判 `待追溯`）。
/// ⇒ **本函数按同一标准处理：在 `RefractiveGlass` 的 provenance 追溯完成前不得对外宣称原创。**
inline float roundedBoxSDF(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

} // namespace cd

/// 折射玻璃：把内容层当作**被折射的背景**，在圆角矩形区域内做透镜位移 + 边缘高光。
///
/// ⚠️ 这是 `layerEffect` 不是 `colorEffect`——它读的是**内容层本身**（`layer.sample`），
/// 因此不能当 `.background { }` 用，只能作用在内容上。
///
/// ⚠️ **不吃时间**：折射由几何驱动，不是动画。按 FR-12，`layerEffect` 类效果冻结时间
/// 输入、保留空间输入——这里干脆没有时间输入，从根上避开 `Float` 精度坑。
[[stitchable]] half4 coreDesignRefractiveGlass(float2 position, SwiftUI::Layer layer,
                                               float2 size, float cornerRadius,
                                               float refraction, float dispersion,
                                               half4 rim) {
    float2 s = max(size, float2(1.0));
    float2 centred = position - s * 0.5;
    float d = cd::roundedBoxSDF(centred, s * 0.5, min(cornerRadius, min(s.x, s.y) * 0.5));

    // 区域外原样透过——玻璃只在自己的形状里起作用。
    float aa = cd::edgeWidth(d);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (inside <= 0.001) {
        return layer.sample(position);
    }

    // 透镜位移：越靠近边缘弯折越强（`d` 为负且接近 0 处最强），中心几乎不动。
    float edgeness = saturate(1.0 + d / max(min(s.x, s.y) * 0.5, 1.0));
    float2 dir = normalize(centred + 1e-5);
    float2 bend = dir * edgeness * edgeness * refraction;

    // ⚠️⚠️ **`layer.sample` 返回的是预乘 alpha 值**（`[R*A, G*A, B*A, A]`）——
    // 依据是 SwiftUI 自己的 `SwiftUI_Metal.h` 里 `Layer::sample` 的文档注释。
    // 下面两段的正确性全都挂在这一条上，改动前务必先读它。
    half4 sample = layer.sample(position - bend);

    // 色散：三通道各偏一点，只在边缘明显。
    //
    // ⚠️ **限制在近乎不透明的区域**（第 3 轮终审 I-6）：预乘语义下三个通道各自被
    // **不同位置的 alpha** 预乘过，把它们拼在一起再配中心采样的 `a`，在半透明区域
    // 会产出 `rgb > a` 的**非法预乘值**。`GlassSymbol` 的符号边缘（抗锯齿像素
    // alpha ∈ (0,1)）最容易暴露。半透明处的色散本就没有良定义 ⇒ 直接不做。
    if (dispersion > 0.0 && sample.a > 0.99h) {
        float2 spread = dir * edgeness * edgeness * refraction * dispersion;
        sample.r = layer.sample(position - bend - spread).r;
        sample.b = layer.sample(position - bend + spread).b;
    }

    // 边缘高光：贴边一圈亮线，宽度用导数推，分辨率无关。
    float rimBand = 1.0 - smoothstep(0.0, aa * 3.0, abs(d));

    // ⚠️⚠️ **预乘空间里的 source-over，两个失效一次消掉**（第 3 轮终审 C-2）。
    // 这一行改过两次，两次都错，原因都是没读上面那条预乘约定：
    //   · 第 1 版 `mix(sample, rim, rimBand * rim.a)` —— `mix` 把 **alpha 一起插值**，
    //     贴边处 `alpha_out ≈ 0.75` ⇒ 不透明内容的边缘被打出约 25% 的**透明环**；
    //   · 第 2 版 `mix(sample, half4(rim.rgb, sample.a), k)` —— 保住了 `sample.a`，
    //     但 `sample.a == 0` 时输出 alpha 恒为 0 ⇒ **透明内容上 rim 整条消失**。
    //     而本仓唯一内建的 rim 使用者 `GlassSymbol` 正是把它施加在 SF Symbol 上，
    //     圆角矩形边框那一圈像素的符号 alpha 基本就是 0 ⇒ **默认路径直接失效**。
    //     （旧版在这一点上反而是对的——这是"用新失效换掉旧失效"。）
    // 正确写法是预乘的 source-over：`out = src + dst × (1 - src.a)`。
    // `alpha_out = src.a + sample.a × (1 - src.a) ≥ sample.a` ⇒ 不透明内容 alpha 不降
    //（无透明环），透明内容上 rim 照常显影，且输出恒为合法预乘值。
    half4 src = rim * half(rimBand);
    return src + sample * (1.0h - src.a);
}
