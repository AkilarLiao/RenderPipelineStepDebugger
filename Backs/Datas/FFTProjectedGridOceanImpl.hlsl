#ifndef FFT_PROJECTED_GRID_OCEAN_IMPL_INCLUDE
#define FFT_PROJECTED_GRID_OCEAN_IMPL_INCLUDE
#include "OceanDisplacement.hlsl"
#include "../../../MyLWRP/Shaders/LightLibs/PBRLighting.hlsl"

#define DISABLE_EDGE_FADE
#define FFT_UNDERWATER_ON
#define _BRDF_FRESNEL
#define M_PI 3.141592657
#define M_SQRT_PI 1.7724538
#define MIN_LIGHT_ATTENUATION 0.5

struct FFTBaseOceanVertexInput
{
    float4 localPosition : POSITION;
    float2 uv : TEXCOORD0;
};

struct FFTBaseOceanVertexOutput
{
    float4 clipPosition : POSITION;
    float4 worldPosition : TEXCOORD0;
    float4 texUV : TEXCOORD1;
    float4 screenPosition : TEXCOORD2;
    half3 vertexLight : TEXCOORD3;
    half3 vertexSH : TEXCOORD4;
#ifdef _MAIN_LIGHT_SHADOWS
    float4 shadowCoord              : TEXCOORD5;
#endif
};

uniform half3 _FoamTint;
uniform float4 _ABSCof;
uniform float4 _SSSCof;
uniform float _TextureWaveFoam;

uniform sampler2D _FoamTexture0;
uniform float4 _FoamTexture0Scale;
uniform float _FoamTexture0ScrollSpeed;

uniform sampler2D _FoamTexture1;
uniform float4 _FoamTexture1Scale;
uniform float _FoamTexture1ScrollSpeed;

uniform sampler2D _PlanarReflectionTexture;

uniform float _ReflectionDistortion;
uniform float _ReflectionRatio;
uniform half4 _ReflectionTintColor;

uniform half4 _ABSTint;
uniform float4 _SSSTint;
uniform half4 _belowTint;

uniform float _FresnelPower;
uniform float _MinFresnel;

uniform sampler2D _PlaneDepthTexture;
uniform float _ReciprocalDepthLimit;

uniform float _DepthBlend;

uniform sampler2D _CopyBackgroundRT;

uniform float _RefractionDistortion;
uniform float _RefractionDensity;

uniform float _AboveInscatterScale;
uniform half4 _AboveInscatterColor;

uniform float _SpecularRoughness;
uniform float _SpecularIntensity;
uniform half3 _OceanColor;

uniform float _FoamVisibility;
uniform float _FoamReducePower;

uniform float _SurfaceSmoothness;
uniform float _SurfaceRoughness;
uniform float _SurfaceMetallic;
#ifdef PROCESS_CAUSTIC_ANIMATION
uniform sampler2D _CausticsMap;
uniform float _CausticsMapScale;
uniform float _CausticsMapReducePower;
#endif
uniform float _VisibilityAttenuation;

#ifdef PROCESS_WATER_DECALSMAP
//uniform sampler2D _WaterDecalsMap;
uniform sampler2D _WaterDecalsRT;
#endif

#ifdef PROCESS_WATER_FLOWSMAP
uniform sampler2D _WaterFlowsRT;
#endif
#ifdef PROCESS_WATER_NORMALSMAP
uniform sampler2D _WaterNormalsRT;
#endif
#ifdef PROCESS_WATER_HEIGHTSMAP
uniform sampler2D _WaterHeightsRT;
#endif

float DecodeFloatRG(float2 enc)
{
    float2 kDecodeDot = float2(1.0, 1 / 255.0);
    return dot(enc, kDecodeDot);
}

FFTBaseOceanVertexOutput FFTProjectedGridOceanVertexProgram(FFTBaseOceanVertexInput input)
{
    //取點效能還是有點差…
    FFTBaseOceanVertexOutput output;
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    float4 uv = float4(input.localPosition.xy, input.uv);
    output.texUV = uv;

    float4 oceanPos;
    float3 displacement;
    OceanPositionAndDisplacement(uv, oceanPos, displacement);
    oceanPos = float4(oceanPos.xyz + displacement, oceanPos.w);


	
    output.worldPosition.xyz = mul(unity_ObjectToWorld, oceanPos.xyz);
    output.worldPosition.w = -mul(UNITY_MATRIX_V, float4(output.worldPosition.xyz, 1.0)).z * _ProjectionParams.w;

    output.clipPosition = TransformWorldToHClip(output.worldPosition);
    output.screenPosition = ComputeScreenPos(output.clipPosition);

#ifdef PROCESS_WATER_HEIGHTSMAP
	//uniform sampler2D _WaterHeightsRT;
	//tex2Dlod(tex, float4(uv, 0, 0));
	float height = tex2Dlod(_WaterHeightsRT, float4(output.screenPosition.xy / output.screenPosition.w, 0, 0)).r;

	height = height * 2.0 - 1.0;

	output.worldPosition.y += 1.5 * height;
	output.worldPosition.w = -mul(UNITY_MATRIX_V, float4(output.worldPosition.xyz, 1.0)).z * _ProjectionParams.w;
	output.clipPosition = TransformWorldToHClip(output.worldPosition);
	output.screenPosition = ComputeScreenPos(output.clipPosition);
#endif

#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
    //output.shadowCoord = GetShadowCoord(vertexInput);
    #if SHADOWS_SCREEN
        output.shadowCoord = ComputeScreenPos(output.clipPosition);
    #else
        output.shadowCoord = TransformWorldToShadowCoord( output.worldPosition);
    #endif
#endif

    output.vertexLight = VertexLighting(output.worldPosition, half3(0.0, 1.0, 0.0));
    OUTPUT_SH(half3(0.0, 1.0, 0.0), output.vertexSH);
    

    return output;
}

//#define FFT_DISABLE_FOAM_TEXTURE
/*
* Applies the foam to the ocean color.
* Spectrum foam in x, overlay foam in y.
*/
half3 OceanWithFoamColor(float3 worldPos, half3 oceanCol, half4 foam, half depth, half withEdgeFoam, half flowRatio)
{
	half foamTexture = 0.0;

#ifndef FFT_DISABLE_FOAM_TEXTURE
    foamTexture += tex2D(_FoamTexture0, (worldPos.xz + _FoamTexture0Scale.z) * _FoamTexture0Scale.xy).r * 2.0;
#else
	foamTexture = 1.0;
#endif

	//Apply texture to the wave foam if that option is enabled.
    foam.x = lerp(foam.x, foam.x * foamTexture, _TextureWaveFoam);
	//Apply texture to overlay foam
    foam.y = foam.y * foamTexture;
   
    half foamAmount = foam.x + foam.y + foam.z;

	//+flowRatio
    
    foamAmount += withEdgeFoam * _FoamVisibility * foamTexture * (pow(1.0 - saturate(depth), _FoamReducePower)  + flowRatio * 0.8);
    
	//apply the absorption coefficient to the foam based on the foam strength.
	//This will fade the foam add make it look like it has some depth and
	//since it uses the abs cof the color should match the water.
    half3 foamCol = _FoamTint * foamAmount * exp(-_ABSCof.rgb * (1.0 - foamAmount) * 1.0);
    return saturate(lerp(oceanCol, foamCol, foamAmount));
}

half3 ReflectionColor(half3 normal, float2 reflectUV)
{	
	reflectUV += normal.xz * _ReflectionDistortion;
	half3 col = tex2Dlod(_PlanarReflectionTexture, half4(reflectUV.xy, 0, 0)).xyz * _ReflectionTintColor;
	return col;
}

/*
* Calculate a subsurface scatter color based on the view, normal and sun dir.
* NOTE - you have to add your directional light onto the ocean component for
* the sun direction to be used. A default sun dir of up is used otherwise.
*/
half3 SubSurfaceScatter(half3 viewDirection, half3 normal, float surfaceDepth, half3 mainLightDirection)
{
	half3 col = half3(0, 0, 0);
#ifdef FFT_UNDERWATER_ON
	//The strength based on the view and up direction.
	half VU = 1.0 - max(0.0, dot(viewDirection, half3(0, 1, 0)));
	VU *= VU;

	//The strength based on the view and sun direction.
	half VS = max(0, dot(reflect(viewDirection, half3(0, 1, 0)) * -1.0, mainLightDirection));
	VS *= VS;
	VS *= VS;

	float NX = abs(dot(normal, half3(1, 0, 0)));

	half s = NX * VU * 0.2 + NX * VU * VS;

	//apply a non linear fade to distance.
	half d = max(0.2, exp(-max(0.0, surfaceDepth)));

	//Apply the absorption coefficient base on the distance and tint final color.
	col = _SSSTint * exp(-_SSSCof.rgb * d * _SSSCof.a) * s;
#endif
	return col;
}

half FresnelAirWater(half3 viewDirection, half3 normal)
{
#ifdef _BRDF_FRESNEL
	half2 v = viewDirection.xz; // view direction in wind space
	half2 t = v * v / (1.0 - viewDirection.y * viewDirection.y); // cos^2 and sin^2 of view direction
	half sigmaV2 = dot(t, 0.004); // slope variance in view direction

	half sigmaV = 0.063;
	half cosThetaV = dot(viewDirection, normal);

    return saturate(_MinFresnel + (1.0 - _MinFresnel) * pow(1.0 - cosThetaV, _FresnelPower * exp(-2.69 * sigmaV)) / (1.0 + 22.7 * pow(sigmaV, 1.5)));
#else
	return saturate(_MinFresnel + (1.0 - _MinFresnel) * pow(1.0 - dot(viewDirection, normal), _FresnelPower));
#endif
}

/*
* The refraction color when see from above the ocean mesh.
* Where depth is normalized between 0-1 based on Ceto_MaxDepthDist.
*/
half3 AboveRefractionColor(float2 screenUV, half3 distortion, float3 surfacePos, float depth)
{
    return _ABSTint * exp(((-_ABSCof.rgb * depth) / _ReciprocalDepthLimit) * _ABSCof.a);
}

/*
* The inscatter when seen from above the ocean mesh.
* Where depth is normalized between 0-1 based on Ceto_MaxDepthDist.
*/
half3 AddAboveInscatter(half3 col, float depth, out float inscatterScaleRatio)
{
	//There are 3 methods used to apply the inscatter.
	half3 inscatterScale;
	inscatterScale.x = saturate(depth * _AboveInscatterScale);
	inscatterScale.y = saturate(1.0 - exp(-depth * _AboveInscatterScale));
	inscatterScale.z = saturate(1.0 - exp(-depth * depth * _AboveInscatterScale));

	//Apply mask to pick which methods result to use.
	//Better than conditional statement?
    inscatterScaleRatio = dot(inscatterScale, float3(0.0, 1.0, 0.0));
    return lerp(col, _AboveInscatterColor.rgb, inscatterScaleRatio * _AboveInscatterColor.a);
}

half2 ProcessDepth(half3 Normal, float2 screenUV, float3 surfacePos, float surfaceDepth,
	float viewDistance, out half3 distortion, out half withEdgeFoam)
{
	float distortionFade = 1.0 - clamp(viewDistance * 0.01, 0.0001, 1.0);
	distortion = Normal * _RefractionDistortion * distortionFade;
    float4 oceanDepth = tex2D(_PlaneDepthTexture, (screenUV + distortion.xz));    
	float2 destDepth = float2(1.0, 0.0);

	destDepth.x = DecodeFloatRG(oceanDepth.rg);
    withEdgeFoam = oceanDepth.b;
    float depthHeight = destDepth.x / _ReciprocalDepthLimit;
    float maxWaterHeight = _WaterHeight + _MaxWaveHeight; 
    depthHeight = maxWaterHeight - depthHeight;
    destDepth.x = depthHeight > surfacePos.y ? 0.0 : (1.0 - exp2(-_VisibilityAttenuation * (surfacePos.y - depthHeight)));
    destDepth = destDepth * oceanDepth.w + (1.0 - oceanDepth.w);
	return destDepth;
}

/*
* The ocean color when seen from above the ocean mesh.
*/
half3 OceanColorFromAbove(half3 N, float2 screenUV, float3 surfacePos, float surfaceDepth, float dist
	, out float Depth, out float depthBlend, out float3 distortion, out float inscatterScaleRatio, out half withEdgeFoam)
{
	Depth = 1.0f;

	half3 col = _OceanColor;

    //half3 distortion;
    float2 oceanDepth = ProcessDepth(N, screenUV, surfacePos, surfaceDepth, dist, distortion, withEdgeFoam);

	depthBlend = lerp(oceanDepth.x, oceanDepth.y, _DepthBlend);

	half3 refraction = AboveRefractionColor(screenUV, distortion, surfacePos, depthBlend);

    refraction = AddAboveInscatter(refraction, depthBlend, inscatterScaleRatio);

	col = lerp(col, refraction, 1.0 - depthBlend);    
	
    Depth = oceanDepth.x;

	return col;
}

half ReflectedSunRadianceFast(half3 V, half3 N, half3 L, half fresnel)
{	
	half3 H = normalize(L + V);

	half hn = dot(H, N);
	half p = exp(-2.0 * ((1.0 - hn * hn) / _SpecularRoughness) / (1.0 + hn)) / (4.0 * M_PI * _SpecularRoughness);

	half zL = dot(L, N);
	half zV = dot(V, N);
	zL = max(zL, 0.01);
	zV = max(zV, 0.01);

	return (L.y < 0 || zL <= 0.0) ? 0.0 : max(_SpecularIntensity * p * sqrt(abs(zL / zV)), 0.0);
}

half3 OceanGlobalIllumination(in half3 worldviewDirection, in half3 worldNormal, in float fresnelTerm, /*in float roughness,*/
	in half3 albedo, in half3 specular, in half occlusion)
{
	half3 reflectVector = reflect(-worldviewDirection, worldNormal);
	half3 indirectDiffuse = half3(0.0, 0.0, 0.0);
#ifdef _PROCESS_VERTEX_SH
	//indirectDiffuse = lightInputData.bakedGI * occlusion;
	//indirectDiffuse = lightInputData.bakedGI;
	indirectDiffuse = SampleSH(worldNormal);
	//indirectDiffuse *= Gamma22ToLinear(occlusion);
#endif

	float perceptualRoughness = 1.0 - _SurfaceSmoothness;
	half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, perceptualRoughness, occlusion);	

	half3 c = indirectDiffuse * albedo;
	float surfaceReduction = 1.0 / (_SurfaceRoughness*_SurfaceRoughness + 1.0);

	half oneMinusReflectivity = OneMinusReflectivityMetallic(_SurfaceMetallic);
	half reflectivity = 1.0 - oneMinusReflectivity;
	float grazingTerm = saturate(_SurfaceSmoothness + reflectivity);

	c += surfaceReduction * indirectSpecular * lerp(specular, grazingTerm, fresnelTerm);
	return c;
}

half3 OceanBRDFLight(half3 albedo, half3 diffuseNormal, half3 tangentSpaceNormal, half3 viewDirection, half fresnel,
	Light mainLight, /*half2 screenUV, */in float4 shadowCoord, out half diffustDot)
{
	half3 result = half3(0.0, 0.0, 0.0);

	half3 V = viewDirection;
	half3 N = tangentSpaceNormal;
	half3 DN = diffuseNormal;
	half occlusion = 1.0;
/*#ifdef _SHADOWS_ENABLED
	half4 shadow = SAMPLE_TEXTURE2D(_ScreenSpaceShadowMapTexture, sampler_ScreenSpaceShadowMapTexture,
		screenUV);
	mainLight.attenuation = max(MIN_LIGHT_ATTENUATION, shadow.r);
	occlusion = 1.0 - shadow.g;
#endif*/

#ifdef _MAIN_LIGHT_SHADOWS
    mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
    mainLight.shadowAttenuation = max(MIN_LIGHT_ATTENUATION, mainLight.shadowAttenuation);
    //occlusion = 1.0 - shadow.g;
#endif


#ifdef OCEAN_UNDERSIDE
	N.y *= -1.0;
	DN.y *= -1.0;
	V.y *= -1.0;
#endif

	half3 spec = ReflectedSunRadianceFast(V, N, mainLight.direction, fresnel);
	//half diff = max(0, dot(DN, mainLight.direction));
    diffustDot = max(0, dot(DN, mainLight.direction));
    half3 lightColor = mainLight.shadowAttenuation * mainLight.color;
    //result.rgb = albedo * lightColor * diff + lightColor * spec;
    result.rgb = albedo * lightColor * diffustDot + lightColor * spec;
	
    #ifdef PROCESS_GI
    result.rgb += OceanGlobalIllumination(viewDirection, diffuseNormal, fresnel, albedo, spec,
		occlusion);
    #endif

	return result;
}

half3 OceanPBRLighting(in half3 albedo, in half3 diffuseNormal, in half3 viewDirection, in float4 shadowCoord,
    in FFTBaseOceanVertexOutput input)
{
    //struct OriginalInputData
    //{
    //    float3 positionWS;
    //    half3 normalWS;
    //    Vector3 viewDirectionWS;
    //    float4 shadowCoord;
    //    half3 vertexLighting;
    //    half3 bakedGI;
    //};
    //output.colorBuffer = OriginalLightweightFragmentPBR(

    /*output.colorBuffer = OriginalLightweightFragmentPBR(
        inputData,
        surfaceData.albedo,
        surfaceData.metallic,
        surfaceData.specular,
        surfaceData.smoothness,
        1.0, //surfaceData.occlusion,
        surfaceData.emission,
        surfaceData.alpha);*/

    OriginalInputData inputData;
    inputData.positionWS = input.worldPosition.xyz;
    inputData.normalWS = normalize(diffuseNormal);
    //inputData.normalWS = half3(0.0, 1.0, 0.0);

    //float3 viewDirection = _WorldSpaceCameraPos - worldPosition;

    inputData.viewDirectionWS = normalize(_WorldSpaceCameraPos - inputData.positionWS);
    inputData.shadowCoord = shadowCoord;
    //inputData.vertexLighting = input.vertexLight;
    inputData.vertexLighting = half3(1.0, 1.0, 1.0);
    //inputData.bakedGI = SampleSHPixel(input.vertexSH, inputData.normalWS);
    inputData.bakedGI = half3(0.0, 0.0, 0.0);

    return OriginalLightweightFragmentPBR(
        inputData,
        albedo,
        0.5, //metallic
        half3(1.0, 1.0, 1.0), //specular
        1.0, //smoothness
        1.0, //occlusion
        0.0, //emission
        1.0).rgb; //alpha
        


    //OriginalLightweightFragmentPBR(
    //    inputData,


    //SAMPLE_GI
    //SampleSHPixel(shName, normalWSName)

    //OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

  //  half3 tangentSpaceNormal = half3(norm3.xy, norm3.z * -1);
  //  resultColor.rgb = OceanBRDFLight(resultColor.rgb, norm3, tangentSpaceNormal, viewDirection, fresnel, mainLight,
		//shadowCoord);

    //return albedo;
}

void OriginalShading(in float2 screenUV, in float3 worldPosition, in half3 norm1, in half3 norm2, in half3 norm3,
	in half4 foam, in half3 viewDirection, in float viewDistance, in float surfaceDepth, in float4 positionUV,
    in float4 shadowCoord, in FFTBaseOceanVertexOutput inputData, out half4 resultColor)
{   
	float3 flowRawDir = float3(0, 0, 0);
	float flowRatio = 0.0;

    //o.Normal = tex2D(_BumpMap, IN.uv_BumpMap.xy) * 2 - 1;

#ifdef PROCESS_WATER_FLOWSMAP
	half4 flowColor = tex2D(_WaterFlowsRT, screenUV);
    flowColor.xy = flowColor.xy * 2.0 - 1.0;

	flowRatio = flowColor.a;
	
	flowRawDir.xz = flowColor.rg;
	flowRawDir.xz = 2.0 * (flowRawDir.xz - float2(0.5, 0.5));

	//_FlowSignX("FlowSignX", Range(-1.0, 1.0)) = 1.0
	//_FlowSignY("FlowSignY", Range(-1.0, 1.0)) = -1.0
	float _FlowSignX = 1;
	float _FlowSignY = -1;
	flowRawDir.xz *= float2(_FlowSignX, _FlowSignY);
	flowRawDir = normalize(flowRawDir);
#endif

	float3 waterNormalDir = float3(0, 0, 0);
	float waterNormalRatio = 0.0;
#ifdef PROCESS_WATER_NORMALSMAP
	half4 normalColor = tex2D(_WaterNormalsRT, screenUV);
	waterNormalDir = normalColor.xyz * 2.0 - 1.0;
	waterNormalRatio = normalColor.a;
#endif

    float3 forward  = float3(0.0, 0.0, 1.0);
    flowRawDir = lerp(forward, flowRawDir, 0.5);	

    norm1 = normalize(lerp(norm1, flowRawDir, flowRatio));
    norm2 = normalize(lerp(norm2, flowRawDir, flowRatio));
    norm3 = normalize(lerp(norm3, flowRawDir, flowRatio));


#ifdef PROCESS_WATER_HEIGHTSMAP
	//uniform sampler2D _WaterHeightsRT;
	//tex2Dlod(tex, float4(uv, 0, 0));
	flowRatio = tex2D(_WaterHeightsRT, screenUV).r;
#endif

	

	/*waterNormalRatio = dot(waterNormalDir, float3(0.0, 0.0, 1.0));
	flowRatio = max(waterNormalRatio, 0.0);
	norm1 = normalize(lerp(norm1, waterNormalDir, max(waterNormalRatio, 0.0)));
	norm2 = normalize(lerp(norm2, waterNormalDir, max(waterNormalRatio, 0.0)));
	norm3 = normalize(lerp(norm3, waterNormalDir, max(waterNormalRatio, 0.0)));*/

    //norm1 = normalize(norm1 + flowRawDir * flowRatio);
    //norm2 = normalize(norm2 + flowRawDir * flowRatio);
    //norm3 = normalize(norm3 + flowRawDir * flowRatio);

	


    float dotValue = dot(viewDirection, norm3);
    float fresnel = FresnelAirWater(viewDirection, norm3);
    
	half3 reflectionColor = ReflectionColor(norm2, screenUV);

    float depth, depthBlend, inscatterScaleRatio;
    float3 distortion;
    half withEdgeFoam;

	half3 destSeaColor = OceanColorFromAbove(norm2, screenUV, worldPosition, surfaceDepth, viewDistance, depth,
		depthBlend, distortion, inscatterScaleRatio, withEdgeFoam);
    
#ifdef PROCESS_CAUSTIC_ANIMATION
    destSeaColor.rgb += saturate(pow(1.0 - depth, _CausticsMapReducePower) * tex2D(_CausticsMap, worldPosition.xz * _CausticsMapScale));
#endif

	Light mainLight = GetMainLight();

	destSeaColor += SubSurfaceScatter(viewDirection, norm1, worldPosition.y, mainLight.direction);


	resultColor = half4(lerp(destSeaColor, reflectionColor, fresnel * _ReflectionRatio), 1.0);

    resultColor.rgb = OceanWithFoamColor(worldPosition, resultColor.rgb, foam, depth, withEdgeFoam, flowRatio);

	
	half3 tangentSpaceNormal = half3(norm3.xy, norm3.z * -1);

    half diffuseDot = 0.0;
	resultColor.rgb = OceanBRDFLight(resultColor.rgb, norm3, tangentSpaceNormal, viewDirection, fresnel, mainLight,
		shadowCoord, diffuseDot);

#ifdef _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    half3 pointLightResult;
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, worldPosition);
        pointLightResult = OceanBRDFLight(resultColor.rgb, norm3, tangentSpaceNormal, viewDirection, fresnel, light,
            shadowCoord, diffuseDot);
        pointLightResult *= light.color * (light.distanceAttenuation * light.shadowAttenuation * diffuseDot);
        resultColor.rgb += pointLightResult;
    }
#endif

    half4 refraction = tex2D(_CopyBackgroundRT, screenUV + distortion.xz * _RefractionDistortion);
    resultColor.rgb = lerp(resultColor.rgb, refraction.rgb, (1.0 - inscatterScaleRatio) * _RefractionDensity);
}



half4 FFTProjectedGridOceanFragmentProgram(FFTBaseOceanVertexOutput input) : SV_Target
{   
    float3 worldPosition = input.worldPosition.xyz;
    float3 viewDirection = _WorldSpaceCameraPos - worldPosition;
    float viewDistance = length(viewDirection);
    viewDirection = normalize(viewDirection);    

	float2 screenUV = input.screenPosition.xy / input.screenPosition.w;
    float dotValue = dot(viewDirection, float3(0.0, 1.0, 0.0));
    float fresnel = pow(1.0 - dotValue, _FresnelPower);
    fresnel = _MinFresnel + (1.0 - _MinFresnel) * fresnel;    

    float4 st = WorldPosToProjectorSpace(worldPosition);
    float3 norm1, norm2, norm3;
    float4 foam;

#ifdef FFT_USE_4_SPECTRUM_GRIDS
	//If 4 grids are being used use 3 normals where...
	//norm1 is grid 0 + 1
	//norm2 is grid 0 + 1 + 2
	//norm3 is grid 0 + 1 + 2 + 3
	//This is done so the shader can use normals of different detail
	
	OceanNormalAndFoam(input.texUV, st, worldPosition, norm1, norm2, norm3, foam);

	if (dot(viewDirection, norm1) < 0.0) norm1 = reflect(norm1, viewDirection);
	if (dot(viewDirection, norm2) < 0.0) norm2 = reflect(norm2, viewDirection);
	if (dot(viewDirection, norm3) < 0.0) norm3 = reflect(norm3, viewDirection);
#else
	//If 2 or 1 grid is being use just use one normal
		//It then needs to be applied to norm1, nor2 and norm3.
	half3 norm;
	OceanNormalAndFoam(input.texUV, st, worldPosition, norm, foam);

	if (dot(viewDirection, norm) < 0.0)
		norm = reflect(norm, viewDirection);

	norm1 = norm;
	norm2 = norm;
	norm3 = norm;
#endif
    
	half4 resultColor;

    float4 shadowCoord = float4(0.0, 0.0, 0.0, 0.0);
#ifdef _MAIN_LIGHT_SHADOWS
    shadowCoord = input.shadowCoord;
#endif

	OriginalShading(screenUV, worldPosition, norm1, norm2, norm3, foam, viewDirection, viewDistance,
		input.worldPosition.w, input.texUV, shadowCoord, input, resultColor);

#ifdef PROCESS_WATER_DECALSMAP
    //half4 decalColor = tex2D(_WaterDecalsMap, screenUV);
	half4 decalColor = tex2D(_WaterDecalsRT, screenUV);	
    resultColor.rgb = lerp(resultColor.rgb, decalColor.rgb, decalColor.a);
	//resultColor.rgb = lerp(resultColor.rgb, half3(1.0, 0.0, 0.0), decalColor.a);
	//resultColor.rgb = decalColor.rgb; //lerp(resultColor.rgb, half3(1.0, 0.0, 0.0), decalColor.a);
#endif


#ifdef PROCESS_WATER_HEIGHTSMAP
	//uniform sampler2D _WaterHeightsRT;
	//tex2Dlod(tex, float4(uv, 0, 0));
	//return float4(tex2D(_WaterHeightsRT, screenUV).rgb * 1000000.0, 1.0);
#endif

    

	return resultColor;
}
#endif//FFT_PROJECTED_GRID_OCEAN_IMPL_INCLUDE