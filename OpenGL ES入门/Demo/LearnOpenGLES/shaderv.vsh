attribute vec2 position;
attribute vec2 textCoordinate;
varying lowp vec2 varyTextCoord;

void main()
{
    varyTextCoord = textCoordinate; // 纹理坐标

    gl_Position = vec4(position, 0, 1); //顶点坐标
}
