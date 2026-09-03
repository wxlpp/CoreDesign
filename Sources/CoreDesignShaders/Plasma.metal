//
//  Plasma.metal
//  CoreDesignShaders
//
//  程序化等离子背景 / Procedural plasma background.
//
//  ⚠️ **自研实现，非移植**（`docs/shader-provenance.md`《第三条出路：自研实现》）。
//  等离子是公开的图形学配方——正弦波叠加后映射到调色斜坡，属**思路层**，不受著作权保护；
//  受保护的是具体实现的表达。本文件按本仓的五轴差异化自研：
//    · 颜色：`.metal` 侧**零硬编码色**，三档全部由 Swift 侧传入（FR-8）
//    · 参数：形参面从 CoreDesign 概念推出（Density / Motion 两个语义档位展开而来），
//      **不是**任何上游的 uniform 列表
//    · a11y：`time` 由 Swift 侧在 Reduce Motion 下冻结，`.metal` 无需知情
//
//  ⚠️ **不要**为了"更像某个参考效果"去增补参数——那会把形参面推向上游的 uniform 列表，
//  正是 `shader-provenance.md` 用来指认来源的那条链。
//

#include <metal_stdlib>
using namespace metal;

namespace {

/// 四相正弦叠加，输出 [0, 1]。
///
/// 经典配方：两个轴向波 + 一个对角波 + 一个径向波。`octaves` 决定叠几层，
/// 每层频率翻倍、幅度减半（标准 FBM 权重），避免高密度档出现可见的条带。
inline float plasmaField(float2 uv, float t, float frequency, int octaves) {
    float value = 0.0;
    float amplitude = 1.0;
    float total = 0.0;
    float f = frequency;

    for (int i = 0; i < octaves; ++i) {
        float2 p = uv * f;
        float axial = sin(p.x + t) + sin(p.y + t * 1.13);
        float diagonal = sin((p.x + p.y) * 0.5 + t * 0.87);
        float radial = sin(length(p - f * 0.5) + t * 1.31);

        value += (axial + diagonal + radial) * 0.25 * amplitude;
        total += amplitude;
        amplitude *= 0.5;
        f *= 2.0;
    }

    // [-1, 1] → [0, 1]
    return saturate(value / max(total, 1e-4) * 0.5 + 0.5);
}

} // namespace

/// 三档调色斜坡。⚠️ 三个颜色**全部来自 Swift 侧**——本文件不持有任何色值。
[[stitchable]] half4 coreDesignPlasma(float2 position,
                                      half4 currentColor,
                                      float2 size,
                                      float time,
                                      float frequency,
                                      float octaves,
                                      half4 low,
                                      half4 mid,
                                      half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float v = plasmaField(uv, time, frequency, int(octaves));

    // 两段线性插值，接缝在 0.5；`smoothstep` 让接缝不出现折线。
    half4 lower = mix(low, mid, half(smoothstep(0.0, 0.5, v)));
    half4 upper = mix(mid, high, half(smoothstep(0.5, 1.0, v)));
    return mix(lower, upper, half(step(0.5, v)));
}
