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
