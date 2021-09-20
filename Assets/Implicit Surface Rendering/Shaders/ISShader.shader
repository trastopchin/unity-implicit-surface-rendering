/*
Implict surface rendering shader.

A lot of this code is taken / adapted from:

1) Jasper Flick's Catlike Coding rendering tutorials
https://catlikecoding.com/unity/tutorials/rendering/

2) Ben Golus's Rendering a Sphere on a Quad Article
https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c#aa33
*/
Shader "Implicit Surfaces/Library/ISShader"
{
    Properties
    {
        // Material properties
        _Color1("Color 1", Color) = (1, 1, 1, 1)
        _Color2("Color 2", Color) = (1, 1, 1, 1)
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        // Impllicit surface rendering algorithm parameters
        _LinearSteps ("Linear Steps", Int) = 256
        _BinarySteps ("Binary Steps", Int) = 4
        _ShadowLinearSteps ("Shadow Caster Linear Steps", Int) = 256
        _ShadowCasterBinarySTeps ("Shadow Caster Binary Steps", Int) = 0
        _DeltaScale ("Delta Scale", Float) = 1.0

        // Implicit surface parameters
        _Position ("Position", Vector) = (0,0,0,1)
        _Scale ("Scale", Vector) = (1,1,1,1)
        _ScaleFactor ("Scale Factor", Float) = 1.0
        _Param1 ("Parameter 1", Float) = 0.0
        _Param2 ("Parameter 2", Float) = 0.0
        _Param3 ("Parameter 3", Float) = 0.0
        _Param4 ("Parameter 4", Float) = 0.0
    }

    SubShader {
        Tags {
            "Queue"="AlphaTest"
            "RenderType"="RaymarchedImplicitSurface"
            "DisableBatching"="True"
        }
        LOD 100

        // Forward base pass for the main directional light
        Pass {
            Tags {
                "LightMode"="ForwardBase"
            }

            CGPROGRAM

            #pragma target 3.0

            #pragma vertex vertexProgram
            #pragma fragment fragmentProgram

            #define FORWARD_BASE_PASS
            #define SHADOWS_SCREEN

            #include "ISLighting.cginc"

            ENDCG
        }

        // Forward add pass for point and spot lights
        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }

            // Add the fragment result to the forward base pass
            Blend One One
            // Disable writing to the zbuffer twice
            ZWrite Off

            CGPROGRAM

            #pragma target 3.0

            /* Creates shader variants each with different keywords defined.
            Includes variants such as DIRECTIONAL, POINT, SPOT, etc. */
            #pragma multi_compile_fwdadd_fullshadows

            #pragma vertex vertexProgram
            #pragma fragment fragmentProgram

            #include "ISLighting.cginc"

            ENDCG
        }

        Pass {
            Tags {
                "LightMode"="ShadowCaster"
            }

            ZWrite On
            ZTest LEqual

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #pragma vertex vertexProgram
            #pragma fragment fragmentProgram

            #include "ISShadows.cginc"

            ENDCG
        }
    }
}
