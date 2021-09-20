/*
Implict surface rendering shadow programs.

A lot of this code is taken / adapted from:

1) Jasper Flick's Catlike Coding rendering tutorials
https://catlikecoding.com/unity/tutorials/rendering/

2) Ben Golus's Rendering a Sphere on a Quad Article
https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c#aa33
*/

#if !defined(IS_SHADOWS)
#define IS_SHADOWS

#include "UnityCG.cginc"
#include "AutoLight.cginc"

// Implicit surface rendering algorithm parameters
int _LinearSteps;
int _BinarySteps;
int _ShadowLinearSteps;
int _ShadowBinarySteps;
float _DeltaScale;

// Implicit surface parameters
float3 _Position;
float3 _Scale;
float _ScaleFactor;

// Additional implicit surface parameters
float _Param1;
float _Param2;
float _Param3;
float _Param4;

#include "ISImplicitSurface.cginc"
#include "ISRendering.cginc"

// Vertex data -> vertex shader
struct VertexData {
  float4 position: POSITION;
};

// Vertex shader -> interpolators -> fragment shader
struct Interpolators {
  float4 clipPos : SV_POSITION;
  float3 rayOrigin : TEXCOORD0;
  float3 rayDir :  TEXCOORD1;
};

// Vertex data -> vertex shader -> interpolators
Interpolators vertexProgram (VertexData v)
{
    Interpolators i;
    i.clipPos = UnityObjectToClipPos(v.position);

    bool isOrtho = UNITY_MATRIX_P._m33 == 1.0;

    // Compute world space position and world space ray direction
    float3 worldPos = mul(unity_ObjectToWorld, float4(v.position.xyz, 1));

    float3 worldSpaceViewPos = UNITY_MATRIX_I_V._m03_m13_m23;

    // Forward in view space is -z, so we want the negative vector
    float3 worldSpaceViewForward = -UNITY_MATRIX_I_V._m02_m12_m22;

    // Originally the perspective ray dir
    float3 worldCameraToPos = worldPos - worldSpaceViewPos;

    // Perspective ray direction and origin
    float3 worldSpaceRayOrigin = worldSpaceViewPos;
    float3 worldSpaceRayDir = worldPos - worldSpaceRayOrigin;

    if (isOrtho) {
      // Orthographic ray direction and origin
      worldSpaceRayDir = worldSpaceViewForward * -dot(worldCameraToPos, worldSpaceViewForward);
      worldSpaceRayOrigin = worldPos - worldSpaceRayDir;
    }

    // We only want to rotate and scale the dir vector, so w = 0
    i.rayDir = mul(unity_WorldToObject, float4(worldSpaceRayDir, 0.0));

    // We need to apply the full transform to the origin vector
    i.rayOrigin = mul(unity_WorldToObject, float4(worldSpaceRayOrigin, 1.0));
    return i;
}

// Fragment shader
half4 fragmentProgram (Interpolators i, out float outDepth : SV_DEPTH) : SV_TARGET
{
    // Initialize ray march
    float3 rayOrigin = i.rayOrigin;
    float3 rayDir = normalize(i.rayDir);

    float2 tSphere = sphereIntersect(rayOrigin, rayDir, float4(0,0,0,0.5));
    clip(tSphere.x);

    // Initialize linear and binary ray march parameters
    int shadowLinearSteps = clamp(_ShadowLinearSteps, 0, 4096);
    int maxShadowBinarySteps = clamp(_ShadowBinarySteps, 0, 4096);
    float3 outsidePoint;
    float3 insidePoint;

    // Compute maximum linear steps proportionate to tSphere.y - tSphere.x
    int maxShadowLinearSteps = round((tSphere.y - tSphere.x) * (float)shadowLinearSteps);

    // Perform initial linear ray march
    int linearRayMarchHit = linearRayMarch(
        rayOrigin, rayDir, tSphere.x, tSphere.y, maxShadowLinearSteps,
        outsidePoint, insidePoint
    );
    clip(linearRayMarchHit);

    // Compute delta for numerical sampling
    float delta = 1e-4*_DeltaScale;

    // Compute intersection point and normal
    float3 objectSpacePos = binaryRayMarch(
        maxShadowBinarySteps, outsidePoint, insidePoint, delta
    );
    float3 objectSpaceNormal = implicitSurfaceNormal(objectSpacePos, delta);

    // Compute clip space position for shadow casters
    float4 clipPos = UnityClipSpaceShadowCasterPos(objectSpacePos, objectSpaceNormal);
    clipPos = UnityApplyLinearShadowBias(clipPos);

    // Write z-depth
    outDepth = clipPos.z / clipPos.w;

    // Handle depth on OpenGL platforms
    #if !defined(UNITY_REVERSED_Z)
        outDepth = outDepth * 0.5 + 0.5;
    #endif

    // TODO: To support OpenGL point lights we need to return depth here
    return 0;
}

#endif
