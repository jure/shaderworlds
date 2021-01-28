# [Shaderworlds](https://shaderworlds.com)

This is an experimental project that allows you to explore shader worlds (think [Shadertoy](https://shadertoy.com)) using WebXR in the browser.

It enables you to move around in the shader worlds (walking, flying) and to interact with the shader worlds by providing controller information to them.
There is even an example where you can paint within a shader.

This is a super early release, but a milestone nonetheless - more docs and features are coming shortly.

# [Demo video](https://twitter.com/JureTriglav/status/1350609805740810240?s=20)
# [High quality demo video](https://www.youtube.com/watch?v=XoRwpPPUAbc&feature=youtu.be)

# Interactions

Please note that this was only tested on a Quest 1 via Oculus Link. If you want to try interactions, all shaders support some kind of movement, either [walking](https://shaderworlds.com/w.html?sculptureII) or [flying](https://shaderworlds.com/w.html?happyjumping), with the left controller thumbstick. Some examples, like the [bubble rings](https://shaderworlds.com/w.html?bubblerings) or [simple path tracer](https://shaderworlds.com/w.html?simplepathtracer) support controller location, try wiggling your controllers around in those worlds! In the [volumetric painting](https://shaderworlds.com/w.html?volumetricpainting) example in addition to controller location, left and right controller triggers create a sphere and box, respectively. Improved interactions, both quantity and quality, are the next stage of this projects.

# Development/contributing

Use `npm install` and `npm start` to build a local & live version of Shaderworlds. Check out `js/index.js` and the examples listed there to figure out how you can add a world.

# Attribution

All of the shaders are listed on the [front page](https://shaderworlds.com) with their origin and attribution. One shader used isn't, as it's 2D and used only for the demo video, but it's still great: https://www.shadertoy.com/view/4sK3RD by Flexi.

