#if !defined(IS_LIGHTING)
#define IS_LIGHTING

// Implicit surface rendering lighting programs

/*
A lot of this code is taken / adapted from:

1) Jasper Flick's Catlike Coding rendering tutorials
https://catlikecoding.com/unity/tutorials/rendering/

2) Ben Golus's Rendering a Sphere on a Quad Article
https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c#aa33
*/

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"

// Material properties
float4 _Color1;
float4 _Color2;
float _Metallic;
float _Smoothness;

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

// Dummy struct for sampling the shadow map
struct shadowInput {
    SHADOW_COORDS(0)
};

// Vertex data -> vertex shader -> interpolators
Interpolators vertexProgram (VertexData v)
{
    Interpolators i;
    i.clipPos = UnityObjectToClipPos(v.position);

    float3 worldPos = mul(unity_ObjectToWorld, float4(v.position.xyz, 1));
    float3 worldSpaceRayDir = worldPos - _WorldSpaceCameraPos.xyz;
    // We only want to rotate and scale the dir vector, so w = 0
    i.rayDir = mul(unity_WorldToObject, float4(worldSpaceRayDir, 0.0));
    // We need to apply the full transform to the origin vector
    i.rayOrigin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1.0));
    return i;
}

// Create UnityLight given world position and normal
UnityLight CreateLight (float4 clipPos, float3 worldPos, float3 normal) {
    UnityLight light;

    // Handle shader variants
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif

    // Handle light types and shadows
    #if defined(SHADOWS_SCREEN)
        // Setup shadow struct for screen space shadows
        shadowInput shadowIN;
        // Screen space directional shadow
        shadowIN._ShadowCoord = ComputeScreenPos(clipPos);
        UNITY_LIGHT_ATTENUATION(attenuation, shadowIN, worldPos);
    #else
        UNITY_LIGHT_ATTENUATION(attenuation, 0, worldPos);
    #endif

    // Set up light
    light.color = _LightColor0.rgb * attenuation;
    light.ndotl = DotClamped(normal, light.dir);
    return light;
}

// Computes box projection reflection direction for sampling refleciton probe
float3 boxProjection (
    float3 direction, float3 position,
    float4 cubemapPosition, float3 boxMin, float3 boxMax
)
{
    // Disable box projection when not supported by target platform
    #if UNITY_SPECCUBE_BOX_PROJECTION
        // If cubemapPosition.w > 0 then the probe should use box projection
        // Also necessary to sample the environment cube when no probe is being used
        // We request and actuail branch because the condition is uniform accross all fragments
        UNITY_BRANCH
        if (cubemapPosition.w > 0) {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            direction = direction * scalar + (position - cubemapPosition);
        }
    #endif
    return direction;
}

// Create UnityIndirect given normal
UnityIndirect CreateIndirectLight (float3 worldPos, float3 normal, float3 viewDir) {

    // Indirect lighting not yet implemented
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    // Manage indirect lighting in the forward base pass
    #if defined(FORWARD_BASE_PASS)

        // Manage spherical harmonics
        indirectLight.diffuse += max(0, ShadeSH9(float4(normal, 1)));

        // Manage reflections
        float3 reflectionDir = reflect(-viewDir, normal);
        Unity_GlossyEnvironmentData envData;
        envData.roughness = 1 - _Smoothness;

        // Sample the 0th reflection probe (or environment cubemap)
        envData.reflUVW = boxProjection(
            reflectionDir, worldPos,
            unity_SpecCube0_ProbePosition,
            unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
        );

        // Handle multiple reflection probes and their transitions
        float3 probe0 = Unity_GlossyEnvironment(
            UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
        );

        // Sample the 1st reflection probe (or environment cubemap)
        envData.reflUVW = boxProjection(
            reflectionDir, worldPos,
            unity_SpecCube1_ProbePosition,
            unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
        );

        // Disable blending when not supported by target platform
        #if UNITY_SPECCUBE_BLENDING
            float interpolator = unity_SpecCube0_BoxMin.w;
            UNITY_BRANCH // Universal branch on whether or not to sample the second reflection probe
            if (interpolator < 0.99999) {
                float3 probe1 = Unity_GlossyEnvironment(
                    UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
                    unity_SpecCube0_HDR, envData
                );

                indirectLight.specular = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
            }
            else {
                indirectLight.specular = probe0;
            }
        #else
            indirectLight.specular = probe0;
        #endif

    #endif

    return indirectLight;
}

// Compute illumination using UNITY_BRDF_PBS
float4 Unity_BRDF_PBS (float3 albedo, float metallic, float smoothness,
                       float4 clipPos, float3 worldPos, float3 normal, float3 viewDir)
{
  float3 specularTint;
  float oneMinusReflectivity;

  // Compute diffuse and specular terms in metallic workflow
  albedo = DiffuseAndSpecularFromMetallic(
    albedo, _Metallic, specularTint, oneMinusReflectivity
  );

  return UNITY_BRDF_PBS(
    albedo, specularTint,
    oneMinusReflectivity, smoothness,
    normal, viewDir,
    CreateLight(clipPos, worldPos, normal), CreateIndirectLight(worldPos, normal, viewDir)
  );
}

// Fragment shader
half4 fragmentProgram (Interpolators i, out float outDepth : SV_DEPTH) : SV_TARGET
{
    // Initialize ray march
    float3 rayOrigin = i.rayOrigin;
    float3 rayDir = normalize(i.rayDir);

    // Intersect bounding sphere
    float2 tSphere = sphereIntersect(rayOrigin, rayDir, float4(0,0,0,0.5));
    clip(tSphere.x);

    // Initialize linear and binary ray march parameters
    int linearSteps = clamp(_LinearSteps, 0, 4096);
    int maxBinarySteps = clamp(_BinarySteps, 0, 4096);
    float3 outsidePoint;
    float3 insidePoint;

    // Compute maximum linear steps proportionate to tSphere.y - tSphere.x
    int maxLinearSteps = round((tSphere.y - tSphere.x) * (float)linearSteps);

    // Perform initial linear ray march
    int linearRayMarchHit = linearRayMarch(
        rayOrigin, rayDir, tSphere.x, tSphere.y, maxLinearSteps,
        outsidePoint, insidePoint
    );
    clip(linearRayMarchHit);

    // Compute delta for numerical sampling
    float delta = 1e-4*_DeltaScale;

    // Compute intersection point and normal
    float3 objectSpacePos = binaryRayMarch(
        maxBinarySteps, outsidePoint, insidePoint, delta
    );
    float3 objectSpaceNormal = implicitSurfaceNormal(objectSpacePos, delta);

    // Compute world position, world normal, and clip position
    float3 worldPos = mul(unity_ObjectToWorld, float4(objectSpacePos, 1.0));
    float3 worldNormal = UnityObjectToWorldNormal(objectSpaceNormal);
    float4 clipPos = UnityObjectToClipPos(float4(objectSpacePos, 1.0));

    // Compute world space viewDir
    float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);

    // Correctly assign Color1 to outside and Color2 to inside
    float facing = dot(viewDir, worldNormal);
    float4 color = facing > 0 ? _Color1 : _Color2;

    // Compute illumination
    float3 lighting = Unity_BRDF_PBS(color, _Metallic, _Smoothness, clipPos,
                                      worldPos, worldNormal, viewDir);

    // Write z-depth
    outDepth = clipPos.z / clipPos.w;

    // Handle depth on OpenGL platforms
    #if !defined(UNITY_REVERSED_Z)
        outDepth = outDepth * 0.5 + 0.5;
    #endif

    // Return color
    return half4(lighting, 1);
}

#endif
