varying lowp vec2 varyTextCoord;

uniform sampler2D colorMap;

precision mediump float;
const vec3 kRec709Luma = vec3(0.2126, 0.7152, 0.0722); // 把rgba转成亮度值

void main()
{
    vec3 textureColor = texture2D(colorMap, varyTextCoord).rgb;
    float gray = dot(textureColor, kRec709Luma);
    gl_FragColor = vec4(gray, gray, gray, 1);
}
