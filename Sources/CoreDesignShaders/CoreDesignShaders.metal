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

/// 二维 hash → [0, 1)。标准的正弦-取小数写法。
inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// 二维 hash → float2。
inline float2 hash22(float2 p) {
    float n = hash21(p);
    return float2(n, hash21(p + n));
}

/// 值噪声：四角 hash 双线性插值，权重用 smoothstep。
inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 w = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
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
                                       half4 background, half4 dot) {
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
    float edge = fwidth(d) * 1.5;
    float mask = 1.0 - smoothstep(r - edge, r + edge, d);

    return mix(background, dot, half(saturate(mask)));
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

    float2 offset = float2(cd::fbm(p + 1.7, int(octaves)),
                           cd::fbm(p + 9.2, int(octaves)));
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
    float2 q = float2(cd::fbm(p, int(octaves)), cd::fbm(p + 5.2, int(octaves)));
    float2 r = float2(cd::fbm(p + wisp * q + 1.7, int(octaves)),
                      cd::fbm(p + wisp * q + 8.3, int(octaves)));
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
                         cd::fbm(p + 4.4 - time * 0.11, 3)) - 0.5;
    float2 q = p + flow * warp;

    // 正弦带 → [0,1]，再用导数做边缘抗锯齿，避免高频带出现摩尔纹。
    float raw = sin((q.x + q.y) * bands) * 0.5 + 0.5;
    float aa = fwidth(raw);
    float v = smoothstep(0.5 - aa, 0.5 + aa, raw);

    // 金属感：把带边处的亮度再抬一档，模拟高光收窄。
    float sheen = pow(saturate(1.0 - abs(raw - 0.5) * 2.0), 3.0);
    return cd::ramp3(saturate(v * 0.75 + sheen * 0.25), low, mid, high);
}

// MARK: - RefractiveGlass（layerEffect）

namespace cd {

/// 圆角矩形 SDF：内部为负、外部为正、边界为 0。
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
    float aa = fwidth(d);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    if (inside <= 0.001) {
        return layer.sample(position);
    }

    // 透镜位移：越靠近边缘弯折越强（`d` 为负且接近 0 处最强），中心几乎不动。
    float edgeness = saturate(1.0 + d / max(min(s.x, s.y) * 0.5, 1.0));
    float2 dir = normalize(centred + 1e-5);
    float2 bend = dir * edgeness * edgeness * refraction;

    // 色散：三通道各偏一点，只在边缘明显。
    half4 sample = layer.sample(position - bend);
    if (dispersion > 0.0) {
        float2 spread = dir * edgeness * edgeness * refraction * dispersion;
        sample.r = layer.sample(position - bend - spread).r;
        sample.b = layer.sample(position - bend + spread).b;
    }

    // 边缘高光：贴边一圈亮线，宽度用导数推，分辨率无关。
    float rimBand = 1.0 - smoothstep(0.0, aa * 3.0, abs(d));
    return mix(sample, rim, half(rimBand * float(rim.a)));
}
