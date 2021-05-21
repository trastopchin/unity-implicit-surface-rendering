////ManagedImplicitSurface
Shader "Implicit Surfaces/My Surfaces/BarthSextic"
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

#if !defined(IS_IMPLICIT_SURFACE)
#define IS_IMPLICIT_SURFACE
float implicitSurface(float3 p)
{
p *= _ScaleFactor * _Scale;
p -= _Position;

float x = p.x;
float y = p.z;
float z = p.y;
float w = _Param1;

float x2 = x*x;
float x3 = x2*x;
float x4 = x2*x2;

float y2 = y*y;
float y4 = y2*y2;

float z2 = z*z;
float z4 = z2*z2;

float w2 = w*w;
float w3 = w2*w;
float w4 = w2*w2;

float phi = (1 + sqrt(5))/ 2;
float phi2 = phi*phi;

float term = (x2+y2+z2-w2);

float value = 4*(phi2*x2 - y2) * (phi2*y2-z2) * (phi2*z2-x2) - (1+2*phi)*term*term*w2;
return -value;
}
#endif

#if !defined(IS_RENDERING)
#define IS_RENDERING

// Implicit surface rendering algorithms and helper functions.

/**
* Numerically sample the implicit surface's normal.
* \param p We compute the implicit surface's normal at this point of the
* implicit surface.
* \param delta The value of delta we use to numerically sample the normal.
*/
float3 implicitSurfaceNormal (float3 p, float delta)
{
    float2 e = float2(delta, 0);
    float dfdx = implicitSurface(p + e.xyy) - implicitSurface(p - e.xyy);
    float dfdy = implicitSurface(p + e.yxy) - implicitSurface(p - e.yxy);
    float dfdz = implicitSurface(p + e.yyx) - implicitSurface(p - e.yyx);
    return normalize(float3(dfdx, dfdy, dfdz));
}

/**
* Linear ray march algorithm.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param tstart The ray equation initial parameter.
* \param tend The ray equation terminal parameter.
* \param maxLinearSteps The maximum number of iterations (linear marching
* steps).
* \param outsidePoint Writes out the last ray point sampled outside of the
* surface.
* \param insidePoint Writes out the last point sampled inside of the surface.
* \return 1 if the ray intersects the implicit surface. 0 otherwise.
*/
int linearRayMarch(float3 e, float3 d, float tstart, float tend,
    int maxLinearSteps, out float3 outsidePoint, out float3 insidePoint)
{
    // Ray march locals
    float3 p = e + d * tstart;
    float3 step = d * (tend-tstart)/float(maxLinearSteps-1);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // Ray march loop
    for (int i = 0; i < maxLinearSteps; i++)
    {
        float fieldValue = signCorrection * implicitSurface(p);

        // Use field value to determine whether or not we're 'inside' the surface
        if (fieldValue < 0.0)
        {
            insidePoint = p;
            outsidePoint = p - step;
            return 1;
        }
        p += step;
    }

    return -1;
}

/**
* Binary ray march algorithm.
* \param maxBinarySteps The maximum number of iterations (binary ray marching
* steps).
* \param outsidePoint The last ray point sampled outside of the surface.
* \param insidePoint The last point sampled inside of the surface.
* \param delta The value of delta we use to numerically sample the surface.
* \return The refined ray-surface intersection point.
*/
float3 binaryRayMarch(int maxBinarySteps, float3 outsidePoint,
    float3 insidePoint, float delta)
{
    // Ray march locals
    float3 p = outsidePoint;
    float3 dir = insidePoint - outsidePoint;
    float3 d = normalize(dir);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // More ray march locals
    float tstart = 0.0;
    float tend = length(dir);
    float tlength = tend / 2.0;

    // Take first binary step
    p += d * tlength;

    // Ray march loop
    for (int i = 0; i < maxBinarySteps; i++) {
        float fieldValue = signCorrection * implicitSurface(p);

        // Half next step distance
        tlength /= 2.0;

        // If close enough to the surface
        if(abs(fieldValue) < delta) {
            break;
        }
        // If still outside proceed forwards
        else if (fieldValue > 0.0) {
            p += d * tlength;
        }
        // If still inside proceed backwards
        else {
            p -= d * tlength;
        }
    }

    // Return the ray-surface intersection point
    return p;
}

/**
* Computes the smallest nonnegative between a and b.
* \param a An input float we are comparing with b.
* \param b An input float we are comparing with a.
* \return The smallest nonnegative between a and b.
*/
float smallestNonnegative(float a, float b) {
    if(a <= b && a >= 0){
        return a;
    }
    else if(b >= 0){
        return b;
    }

    if(b <= a && b >= 0){
        return b;
    }
    else if(a >= 0){
        return a;
    }

    return -1;
}

/**
* Computes the ray parameter for a ray-box intersection.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param boxSize The dimensions of the origin-centered box.
* \return The ray parameter t if there is a ray-box intersection and otherwise
* -1.
*/
float boxIntersect(float3 e, float3 d, float3 boxSize)
{
  float3 v;

  // x planes
  float t1 = (boxSize.x - e.x) / d.x;
  v = e + t1 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t1 = -1;

  float t2 = (-boxSize.x - e.x) / d.x;
  v = e + t2 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t2 = -1;

  // y planes
  float t3 = (boxSize.y - e.y) / d.y;
  v = e + t3 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t3 = -1;

  float t4 = (-boxSize.y - e.y) / d.y;
  v = e + t4 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t4 = -1;

  // z planes
  float t5 = (boxSize.z - e.z) / d.z;
  v = e + t5 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t5 = -1;

  // z planes
  float t6 = (-boxSize.z - e.z) / d.z;
  v = e + t6 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t6 = -1;

  float t = smallestNonnegative(smallestNonnegative(smallestNonnegative(t1, t2), smallestNonnegative(t3, t4)), smallestNonnegative(t5, t6));
  return t;
}

/**
* Computes the two ray parameters for a ray-sphere intersection.
* \param ro The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param sph A vector where the first three components represent the sphere
* center and the last component represents the sphere radius.
* \return If there is a ray-sphere intersection, a vector where the first
* and second components hold the smaller and larger ray parameters,
* respectively. Otherwise returns (-1.0, -1.0);
*
* https://iquilezles.org/www/articles/intersectors/intersectors.htm
*/
float2 sphereIntersect(float3 ro, float3 rd, float4 sph)
{
  float3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - sph.w*sph.w;
  float h = b*b-c;
  if (h<0.0) return float2(-1.0, -1.0);
  h = sqrt(h);
  return float2(-b-h, -b+h);
}

#endif


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

#if !defined(IS_IMPLICIT_SURFACE)
#define IS_IMPLICIT_SURFACE
float implicitSurface(float3 p)
{
p *= _ScaleFactor * _Scale;
p -= _Position;

float x = p.x;
float y = p.z;
float z = p.y;
float w = _Param1;

float x2 = x*x;
float x3 = x2*x;
float x4 = x2*x2;

float y2 = y*y;
float y4 = y2*y2;

float z2 = z*z;
float z4 = z2*z2;

float w2 = w*w;
float w3 = w2*w;
float w4 = w2*w2;

float phi = (1 + sqrt(5))/ 2;
float phi2 = phi*phi;

float term = (x2+y2+z2-w2);

float value = 4*(phi2*x2 - y2) * (phi2*y2-z2) * (phi2*z2-x2) - (1+2*phi)*term*term*w2;
return -value;
}
#endif

#if !defined(IS_RENDERING)
#define IS_RENDERING

// Implicit surface rendering algorithms and helper functions.

/**
* Numerically sample the implicit surface's normal.
* \param p We compute the implicit surface's normal at this point of the
* implicit surface.
* \param delta The value of delta we use to numerically sample the normal.
*/
float3 implicitSurfaceNormal (float3 p, float delta)
{
    float2 e = float2(delta, 0);
    float dfdx = implicitSurface(p + e.xyy) - implicitSurface(p - e.xyy);
    float dfdy = implicitSurface(p + e.yxy) - implicitSurface(p - e.yxy);
    float dfdz = implicitSurface(p + e.yyx) - implicitSurface(p - e.yyx);
    return normalize(float3(dfdx, dfdy, dfdz));
}

/**
* Linear ray march algorithm.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param tstart The ray equation initial parameter.
* \param tend The ray equation terminal parameter.
* \param maxLinearSteps The maximum number of iterations (linear marching
* steps).
* \param outsidePoint Writes out the last ray point sampled outside of the
* surface.
* \param insidePoint Writes out the last point sampled inside of the surface.
* \return 1 if the ray intersects the implicit surface. 0 otherwise.
*/
int linearRayMarch(float3 e, float3 d, float tstart, float tend,
    int maxLinearSteps, out float3 outsidePoint, out float3 insidePoint)
{
    // Ray march locals
    float3 p = e + d * tstart;
    float3 step = d * (tend-tstart)/float(maxLinearSteps-1);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // Ray march loop
    for (int i = 0; i < maxLinearSteps; i++)
    {
        float fieldValue = signCorrection * implicitSurface(p);

        // Use field value to determine whether or not we're 'inside' the surface
        if (fieldValue < 0.0)
        {
            insidePoint = p;
            outsidePoint = p - step;
            return 1;
        }
        p += step;
    }

    return -1;
}

/**
* Binary ray march algorithm.
* \param maxBinarySteps The maximum number of iterations (binary ray marching
* steps).
* \param outsidePoint The last ray point sampled outside of the surface.
* \param insidePoint The last point sampled inside of the surface.
* \param delta The value of delta we use to numerically sample the surface.
* \return The refined ray-surface intersection point.
*/
float3 binaryRayMarch(int maxBinarySteps, float3 outsidePoint,
    float3 insidePoint, float delta)
{
    // Ray march locals
    float3 p = outsidePoint;
    float3 dir = insidePoint - outsidePoint;
    float3 d = normalize(dir);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // More ray march locals
    float tstart = 0.0;
    float tend = length(dir);
    float tlength = tend / 2.0;

    // Take first binary step
    p += d * tlength;

    // Ray march loop
    for (int i = 0; i < maxBinarySteps; i++) {
        float fieldValue = signCorrection * implicitSurface(p);

        // Half next step distance
        tlength /= 2.0;

        // If close enough to the surface
        if(abs(fieldValue) < delta) {
            break;
        }
        // If still outside proceed forwards
        else if (fieldValue > 0.0) {
            p += d * tlength;
        }
        // If still inside proceed backwards
        else {
            p -= d * tlength;
        }
    }

    // Return the ray-surface intersection point
    return p;
}

/**
* Computes the smallest nonnegative between a and b.
* \param a An input float we are comparing with b.
* \param b An input float we are comparing with a.
* \return The smallest nonnegative between a and b.
*/
float smallestNonnegative(float a, float b) {
    if(a <= b && a >= 0){
        return a;
    }
    else if(b >= 0){
        return b;
    }

    if(b <= a && b >= 0){
        return b;
    }
    else if(a >= 0){
        return a;
    }

    return -1;
}

/**
* Computes the ray parameter for a ray-box intersection.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param boxSize The dimensions of the origin-centered box.
* \return The ray parameter t if there is a ray-box intersection and otherwise
* -1.
*/
float boxIntersect(float3 e, float3 d, float3 boxSize)
{
  float3 v;

  // x planes
  float t1 = (boxSize.x - e.x) / d.x;
  v = e + t1 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t1 = -1;

  float t2 = (-boxSize.x - e.x) / d.x;
  v = e + t2 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t2 = -1;

  // y planes
  float t3 = (boxSize.y - e.y) / d.y;
  v = e + t3 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t3 = -1;

  float t4 = (-boxSize.y - e.y) / d.y;
  v = e + t4 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t4 = -1;

  // z planes
  float t5 = (boxSize.z - e.z) / d.z;
  v = e + t5 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t5 = -1;

  // z planes
  float t6 = (-boxSize.z - e.z) / d.z;
  v = e + t6 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t6 = -1;

  float t = smallestNonnegative(smallestNonnegative(smallestNonnegative(t1, t2), smallestNonnegative(t3, t4)), smallestNonnegative(t5, t6));
  return t;
}

/**
* Computes the two ray parameters for a ray-sphere intersection.
* \param ro The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param sph A vector where the first three components represent the sphere
* center and the last component represents the sphere radius.
* \return If there is a ray-sphere intersection, a vector where the first
* and second components hold the smaller and larger ray parameters,
* respectively. Otherwise returns (-1.0, -1.0);
*
* https://iquilezles.org/www/articles/intersectors/intersectors.htm
*/
float2 sphereIntersect(float3 ro, float3 rd, float4 sph)
{
  float3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - sph.w*sph.w;
  float h = b*b-c;
  if (h<0.0) return float2(-1.0, -1.0);
  h = sqrt(h);
  return float2(-b-h, -b+h);
}

#endif


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


            ENDCG
        }

        Pass {
            Tags {
                "LightMode"="ShadowCaster"
            }

            ZWrite On
            ZTest LEqual

            CGPROGRAM

            #pragma target 5.0

            #pragma multi_compile_shadowcaster

            #pragma vertex vertexProgram
            #pragma fragment fragmentProgram

            #if !defined(IS_SHADOWS)
#define IS_SHADOWS

// Implict surface rendering shadow programs.

/*
A lot of this code is taken / adapted from:

1) Jasper Flick's Catlike Coding rendering tutorials
https://catlikecoding.com/unity/tutorials/rendering/

2) Ben Golus's Rendering a Sphere on a Quad Article
https://bgolus.medium.com/rendering-a-sphere-on-a-quad-13c92025570c#aa33
*/

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

#if !defined(IS_IMPLICIT_SURFACE)
#define IS_IMPLICIT_SURFACE
float implicitSurface(float3 p)
{
p *= _ScaleFactor * _Scale;
p -= _Position;

float x = p.x;
float y = p.z;
float z = p.y;
float w = _Param1;

float x2 = x*x;
float x3 = x2*x;
float x4 = x2*x2;

float y2 = y*y;
float y4 = y2*y2;

float z2 = z*z;
float z4 = z2*z2;

float w2 = w*w;
float w3 = w2*w;
float w4 = w2*w2;

float phi = (1 + sqrt(5))/ 2;
float phi2 = phi*phi;

float term = (x2+y2+z2-w2);

float value = 4*(phi2*x2 - y2) * (phi2*y2-z2) * (phi2*z2-x2) - (1+2*phi)*term*term*w2;
return -value;
}
#endif

#if !defined(IS_RENDERING)
#define IS_RENDERING

// Implicit surface rendering algorithms and helper functions.

/**
* Numerically sample the implicit surface's normal.
* \param p We compute the implicit surface's normal at this point of the
* implicit surface.
* \param delta The value of delta we use to numerically sample the normal.
*/
float3 implicitSurfaceNormal (float3 p, float delta)
{
    float2 e = float2(delta, 0);
    float dfdx = implicitSurface(p + e.xyy) - implicitSurface(p - e.xyy);
    float dfdy = implicitSurface(p + e.yxy) - implicitSurface(p - e.yxy);
    float dfdz = implicitSurface(p + e.yyx) - implicitSurface(p - e.yyx);
    return normalize(float3(dfdx, dfdy, dfdz));
}

/**
* Linear ray march algorithm.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param tstart The ray equation initial parameter.
* \param tend The ray equation terminal parameter.
* \param maxLinearSteps The maximum number of iterations (linear marching
* steps).
* \param outsidePoint Writes out the last ray point sampled outside of the
* surface.
* \param insidePoint Writes out the last point sampled inside of the surface.
* \return 1 if the ray intersects the implicit surface. 0 otherwise.
*/
int linearRayMarch(float3 e, float3 d, float tstart, float tend,
    int maxLinearSteps, out float3 outsidePoint, out float3 insidePoint)
{
    // Ray march locals
    float3 p = e + d * tstart;
    float3 step = d * (tend-tstart)/float(maxLinearSteps-1);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // Ray march loop
    for (int i = 0; i < maxLinearSteps; i++)
    {
        float fieldValue = signCorrection * implicitSurface(p);

        // Use field value to determine whether or not we're 'inside' the surface
        if (fieldValue < 0.0)
        {
            insidePoint = p;
            outsidePoint = p - step;
            return 1;
        }
        p += step;
    }

    return -1;
}

/**
* Binary ray march algorithm.
* \param maxBinarySteps The maximum number of iterations (binary ray marching
* steps).
* \param outsidePoint The last ray point sampled outside of the surface.
* \param insidePoint The last point sampled inside of the surface.
* \param delta The value of delta we use to numerically sample the surface.
* \return The refined ray-surface intersection point.
*/
float3 binaryRayMarch(int maxBinarySteps, float3 outsidePoint,
    float3 insidePoint, float delta)
{
    // Ray march locals
    float3 p = outsidePoint;
    float3 dir = insidePoint - outsidePoint;
    float3 d = normalize(dir);

    // Compute initial field sign to differentiate the 'inside' and 'oustside'
    float signCorrection = sign(implicitSurface(p));

    // More ray march locals
    float tstart = 0.0;
    float tend = length(dir);
    float tlength = tend / 2.0;

    // Take first binary step
    p += d * tlength;

    // Ray march loop
    for (int i = 0; i < maxBinarySteps; i++) {
        float fieldValue = signCorrection * implicitSurface(p);

        // Half next step distance
        tlength /= 2.0;

        // If close enough to the surface
        if(abs(fieldValue) < delta) {
            break;
        }
        // If still outside proceed forwards
        else if (fieldValue > 0.0) {
            p += d * tlength;
        }
        // If still inside proceed backwards
        else {
            p -= d * tlength;
        }
    }

    // Return the ray-surface intersection point
    return p;
}

/**
* Computes the smallest nonnegative between a and b.
* \param a An input float we are comparing with b.
* \param b An input float we are comparing with a.
* \return The smallest nonnegative between a and b.
*/
float smallestNonnegative(float a, float b) {
    if(a <= b && a >= 0){
        return a;
    }
    else if(b >= 0){
        return b;
    }

    if(b <= a && b >= 0){
        return b;
    }
    else if(a >= 0){
        return a;
    }

    return -1;
}

/**
* Computes the ray parameter for a ray-box intersection.
* \param e The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param boxSize The dimensions of the origin-centered box.
* \return The ray parameter t if there is a ray-box intersection and otherwise
* -1.
*/
float boxIntersect(float3 e, float3 d, float3 boxSize)
{
  float3 v;

  // x planes
  float t1 = (boxSize.x - e.x) / d.x;
  v = e + t1 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t1 = -1;

  float t2 = (-boxSize.x - e.x) / d.x;
  v = e + t2 * d;
  if (abs(v.z) > boxSize.z || abs(v.y) > boxSize.y)
    t2 = -1;

  // y planes
  float t3 = (boxSize.y - e.y) / d.y;
  v = e + t3 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t3 = -1;

  float t4 = (-boxSize.y - e.y) / d.y;
  v = e + t4 * d;
  if (abs(v.z) > boxSize.z || abs(v.x) > boxSize.x)
    t4 = -1;

  // z planes
  float t5 = (boxSize.z - e.z) / d.z;
  v = e + t5 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t5 = -1;

  // z planes
  float t6 = (-boxSize.z - e.z) / d.z;
  v = e + t6 * d;
  if (abs(v.x) > boxSize.x || abs(v.y) > boxSize.y)
    t6 = -1;

  float t = smallestNonnegative(smallestNonnegative(smallestNonnegative(t1, t2), smallestNonnegative(t3, t4)), smallestNonnegative(t5, t6));
  return t;
}

/**
* Computes the two ray parameters for a ray-sphere intersection.
* \param ro The ray origin (eye).
* \param d The ray direction. Normalized as a precondition.
* \param sph A vector where the first three components represent the sphere
* center and the last component represents the sphere radius.
* \return If there is a ray-sphere intersection, a vector where the first
* and second components hold the smaller and larger ray parameters,
* respectively. Otherwise returns (-1.0, -1.0);
*
* https://iquilezles.org/www/articles/intersectors/intersectors.htm
*/
float2 sphereIntersect(float3 ro, float3 rd, float4 sph)
{
  float3 oc = ro - sph.xyz;
  float b = dot(oc, rd);
  float c = dot(oc, oc) - sph.w*sph.w;
  float h = b*b-c;
  if (h<0.0) return float2(-1.0, -1.0);
  h = sqrt(h);
  return float2(-b-h, -b+h);
}

#endif


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


            ENDCG
        }
    }
}

