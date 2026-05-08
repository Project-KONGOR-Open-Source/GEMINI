// (C)2006 Garena Shanghai
// math.h
// 
// Basic math operations
//=============================================================================

//=============================================================================
// Global variables
//=============================================================================


//=============================================================================
// Functions
//=============================================================================


float2 UVRotate(float2 vUV, float fAngle)
{
	float sinAngle = sin(fAngle);
	float cosAngle = cos(fAngle);

	float vUVCentered = vUV - 0.5f;

	float2x2 mRot = float2x2(cosAngle, sinAngle, -sinAngle, cosAngle);
	vUVCentered = mul(vUVCentered, mRot);

	vUV = vUVCentered + 0.5f;

	return vUV;
}
