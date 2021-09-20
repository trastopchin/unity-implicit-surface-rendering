// Implicit surface function definition.

#if !defined(IS_IMPLICIT_SURFACE)
#define IS_IMPLICIT_SURFACE

float implicitSurface(float3 p)
{
    // Scale and transform the point
    p *= _ScaleFactor * _Scale;
    p -= _Position;

    float x = p.x;
    float x2 = x*x;

    float y = p.z;
    float y2 = y*y;

    float z = p.y;
    float z2 = z*z;

    // Kummer surface equation
    float mu = _Param1;
    float mu2 = mu*mu;
    float lambda = (3.0 * mu * mu - 1.0) / (3 - mu * mu);

    float root2 = pow(2.0, 0.5);
    float p0 = 1 - z - root2 * x;
    float q0 = 1 - z + root2 * x;
    float r0 = 1 + z + root2 * y;
    float s0 = 1 + z - root2 * y;

    float term1 = (x2 + y2 + z2- mu2);

    return term1*term1 - lambda * p0 * q0 * r0 * s0;
}

#endif
