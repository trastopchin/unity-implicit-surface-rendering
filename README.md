# Unity Implicit Surface Rendering

A set of shader blueprints and tools that allow users to create and render implicit surfaces in Unity. Created for the Grinnell College Immersive Experiences Lab.

<p align="center">
  <img src="/Images/two_implicit_surfaces.png" alt="Two implicit surfaces rendered within Unity. The one on the left is a blue Goursat surface and the one on the right is a red Kummer surface." width="800">
</p>

This project builds on Ben Golus' [Rendering a Sphere on a Quad article](https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c), Jasper Flick's [Catlike Coding Unity Rendering Tutorials](https://catlikecoding.com/unity/tutorials/rendering/), and Tal Rastopchin's [AIT-GC-3D-Ray-Marching project](https://github.com/trastopchin/AIT-CG-3D-Ray-Marching).

## Features

1. The implicit surface shader blueprint uses a combination of linear and binary ray marching to render implicit surfaces. It supports directional, point, and spot lights; shadow casting and shadow recieving; and sampling reflection probes.

2. A demo scene containing four example interactive implicit surfaces. The player can walk around the scene using the WASD keys. When the player is close enough to an implicit surface, they can use the Q and E keys to manipulate a parameter of the implicit surface function.

3. A simple set of tools that allows users to create new shaders based on a specified implicit surface function.

## How To Use

Download this project and unzip it. Open the unzipped folder as a preexisting project from within the Unity Hub. To create a new implicit surface, you need to

1. Open the Implicit Surfaces window (Window/Rendering/Implicit Surfaces).
2. Create a new cube (GameObject/3D Object/Cube).
3. Create a new material and name it appropriately (Assets/Create/Material). Make sure it’s in a folder like Assets/Example Scenes/Materials.
4. Apply this material to the cube that you just created. One way you can do this is by dragging and dropping it onto the cube you just created. Another way you can do this is by manually setting the material field in the Mesh Render component of the cube you created.
5.	After you’ve created a new cube and applied a new material to it, you can select it and you will be able to use the Implicit Surfaces window.

At this point you need to
1.	Select the cube you just made.
2.	Specify a new unique shader name like “SurfaceName.”
3.	Fill out the function input with something like:

```HLSL
p *= _ScaleFactor * _Scale;
p -= _Position;

float x = p.x;
float y = p.z;
float z = p.y;
float a = _Param1;
float b = _Param2;
float c = _Param3;

float x2 = x*x;
float x3 = x2*x;
float x4 = x2*x2;

float y2 = y*y;
float y3 = y2*y;
float y4 = y2*y2;

float z2 = z*z;
float z3 = z2*z;
float z4 = z2*z2;

float term = (x2 + y2 + z2);

return x4 + y4 + z4 + a*term*term +b*term + c;
```
This is an implicit surface function for a Goursat surface. Now you need to

1.	Make sure “Apply Shader to Selected Material?” and “Delete previous shader?” are true
2.	Click generate shader.

If there were no shader compiler errors, at this point that cube should render the implicit surface you specified. You can then edit the parameters of the material either by selecting the cube and scrolling to the bottom of the inspector or by selecting the material that you made and placed within the Assets/Example Scenes/Materials folder. T

## Shader Properties Documentation

The main parameters to adjust are
- Color 1 (the facing color) and Color 2 (the back facing color)
- The metallic and smoothness material properties
- The position, scale, and scale factor
- As well as the parameters 1, 2, … (which directly correspond to _Param1, _Param2, … , in the implicit surface function definition).

You can also specify the resolution of the ray marching algorithm by adjusting
- The linear steps which are the maximum number of iterations linear ray marching algorithm used in the base and forward add passes.
- The binary steps which are the maximum number of iterations binary ray marching refinement algorithm used in the base and forward add passes.
- The binary steps which are the maximum number of iterations binary ray marching refinement algorithm used in the shadow caster and receiver passes.

## Future Work

### Performance
- An easy way to improe the performance of the shader is to decrease the maximum amount of linear steps using distance away from the camera as a metric. This could work similarly to shadow cascades, rendering with better resolutions when we are closer to implicit surfaces and lower resolutions when we are sufficiently far away.
- A very good way to improve the performance of this shader would be to implement it using the defered shading rendering path. This can especially speed up the forward add passes by not having to re-run the entire ray marching algorithm for each additional light.
- Another way we could speed up the peformance of the ray marching algorithm is by

### Features
- We could implement Ben Golus' ideas of rendering the implicit surface on a quad and being smart about how we perform our ray marching in order to allow lights to get arbitarily close to our surfaces (as opposed to outside their bounding cubes).
- We could overhaul the shader generation system. The tool works, but it's a brute force solution to the problem. It specifically runs the risk of creating shaders that end up never being deleted when they are not used as well as forcing the asset database to refresh when writing new shaders.
- Right now the creation of shaders sometimes results in inconsistent line endings. This could be fixed.

## Built With

* [Unity](https://unity3d.com/)
* [Blender](https://www.blender.org/)

## Sources

* [Rendering a Sphere on a Quad](https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c) - Ben Golus' article on raytracing a single sphere on a quad.
* [Unity Rendering Tutorials](https://catlikecoding.com/unity/tutorials/rendering/) - Jasper Flick's rendering tutorials and code (MIT0 license).
* [AIT-GC-3D-Ray-Marching](https://github.com/trastopchin/AIT-CG-3D-Ray-Marching) - Tal Rastopchin's Fall 2019 AIT computer graphics course ray marching project.

## License

The contents of this repository use a MIT No Attribution (MIT-0) license.
