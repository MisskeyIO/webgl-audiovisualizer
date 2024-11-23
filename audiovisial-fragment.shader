/*
MIT License

Copyright (c) 2024 tar_bin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

precision mediump float;
uniform float time;
uniform float enableAudio;
uniform sampler2D tAudioData1;
uniform sampler2D tAudioData2;
uniform vec2 resolution;
uniform sampler2D uTex;
uniform sampler2D uMask;
varying vec2 vUv;

const float PI  = 3.141592653589793;
const float PI2 = PI * 2.;
const float oneStep = 1.0 / 32.0;

vec2 cubicBezier(vec2 a, vec2 b, vec2 c, vec2 d, float q) {
    vec2 qab = mix(a, b, q);
    vec2 qbc = mix(b, c, q);
    vec2 qcd = mix(c, d, q);
    vec2 qabc = mix(qab, qbc, q);
    vec2 qbcd = mix(qbc, qcd, q);
    return mix(qabc, qbcd, q);
}

float circle(vec2 uv, float audioA, float audioB, float angle) {
    float ratioInStep = fract(angle / oneStep);
    float size = cubicBezier(vec2(-1.0, audioA), vec2(0.0, audioA), vec2(0.0, audioB), vec2(1.0, audioB), ratioInStep).y;
    return step(length(uv), (size * 3.0) - 0.8);
}

float stepValue(float value, float stepSize) {
    return floor(value / stepSize) * stepSize;
}

void main() {
    vec2 uv = (gl_FragCoord.xy * 2.0 - resolution) / min(resolution.x, resolution.y);
    vec2 texUv = uv / 0.8 + 0.5;

    // ベクトルから角度を取得して正規化
    float angle = fract(atan(uv.y, uv.x) / PI2); // 0.0 ~ 1.0

    // 分解能に補正した角度
    float stepAngle = stepValue(angle, oneStep);

    // ビジュアライザ
    float shape1 = 0.0;
    float shape2 = 0.0;
    if (enableAudio < 0.5) {
        // 停止時は描画しない
    } else {
        // 音声解析情報
        float xA;
        float xB;

        if (angle < 0.5) {
            xA = stepAngle * 2.0;
            xB = (stepAngle + oneStep) * 2.0;
        } else {
            xA = 1.0 - (stepAngle - 0.5) * 2.0;
            xB = 1.0 - (stepAngle + oneStep - 0.5) * 2.0;
        }

        // レイヤー1
        float audio1A = sin(texture2D(tAudioData1, vec2(xA, 0.0)).r);
        float audio1B = sin(texture2D(tAudioData1, vec2(xB, 0.0)).r);
        shape1 = circle(uv, audio1A, audio1B, angle) > 0.0 ? 1.0 : 0.0;

        // レイヤー2
        float audio2A = sin(texture2D(tAudioData2, vec2(xA, 0.0)).r);
        float audio2B = sin(texture2D(tAudioData2, vec2(xB, 0.0)).r);
        shape2 = circle(uv, audio2A, audio2B, angle) > 0.0 ? 1.0 : 0.0;
    }

    // プロフィール画像と円形クリップ
    vec3 profileTex = texture2D(uTex, texUv).rgb;
    vec3 maskTex = texture2D(uMask, texUv).rgb;

    // 背景色をピックアップしてミックス
    vec3 pickColor1 = texture2D(uTex, vec2(0.3, 0.3)).rgb;
    vec3 pickColor2 = texture2D(uTex, vec2(0.7, 0.7)).rgb;
    vec3 pickColor = mix(pickColor1, pickColor2, 0.5);

    // 背景と各レイヤーを合成
    vec3 backColor = mix(pickColor, vec3(0.0), 0.1);
    backColor = mix(backColor, mix(pickColor, vec3(1.0), 0.2), shape1);
    backColor = mix(backColor, mix(pickColor, vec3(1.0), 0.5), shape2);
    vec3 mixedTex = backColor;
    if (texUv.x >= 0. && texUv.x <= 1. && texUv.y >= 0. && texUv.y <= 1.) {
        mixedTex = mix(profileTex, backColor, maskTex.r);
    }
    
    gl_FragColor = vec4(mixedTex, 1.0);
}