#ifdef GL_ES
    precision mediump float;
#endif

uniform float u_mouseButton; 

void main() {
    float pressed = step(0.5, u_mouseButton); // returns 0.0 if u_mouseButton < 0.5, else 1.0
    gl_FragColor = vec4(vec3(pressed), 1.0);
}