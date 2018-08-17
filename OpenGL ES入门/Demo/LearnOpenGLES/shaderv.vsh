attribute vec2 position;
attribute vec2 textCoordinate;
varying lowp vec2 varyTextCoord;

void main()
{
    varyTextCoord = textCoordinate;
    
    gl_Position = vec4(position, 0, 1);
}
