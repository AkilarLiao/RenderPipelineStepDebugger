#ifndef WATER_FLOWS_IMPL_INCLUDED
#define WATER_FLOWS_IMPL_INCLUDED

#include "UnityCG.cginc"            

struct VertexInput
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    half4 color : COLOR;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    float4 vertex : SV_POSITION;
    float2 uv : TEXCOORD0;
    half4 color : COLOR;
	// necessary only if you want to access instanced properties in fragment Shader.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


UNITY_INSTANCING_BUFFER_START(Props)	
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(Props)

sampler2D _FlowsMap;
uniform float _FlowIntensity;
uniform float _FlowSignX;
uniform float _FlowSignY;
uniform float _Speed;
uniform float _MinRatio;
#if defined(PROCESS_ANIMATED_STEP_UV)
uniform float _RowCount;
uniform float _ColumnCount;
#else
sampler2D _PhaseMap;
#endif

#ifdef PROCESS_ANIMATED_STEP_UV
half2 ProcessStepAnimateUV(in half2 UV)
{
    half2 ResultUV = UV;
    float RangeRatio = _Time.y * _Speed;
    float RangeIndex = fmod(RangeRatio, _RowCount * _ColumnCount);
    float RowIndex = floor(fmod(_RowCount - RangeIndex / _ColumnCount, _RowCount));
    float ColumnIndex = floor(fmod(RangeIndex, _ColumnCount));
    half2 SetpUV = half2(1.0 / _ColumnCount, 1.0 / _RowCount);
    ResultUV.x = saturate((ResultUV.x + ColumnIndex) * SetpUV.x);
    ResultUV.y = saturate((ResultUV.y + RowIndex) * SetpUV.y);
    return ResultUV;
}
#endif

VertexOutput WaterFlowVertexProgram(VertexInput input)
{
    VertexOutput output;
    UNITY_SETUP_INSTANCE_ID(input);
	// necessary only if you want to access instanced properties in the fragment Shader.
    UNITY_TRANSFER_INSTANCE_ID(input, output);

    output.vertex = UnityObjectToClipPos(input.vertex);

#if defined(PROCESS_ANIMATED_STEP_UV)
    output.uv = ProcessStepAnimateUV(input.uv);
#else
    output.uv = input.uv;
#endif
    output.color = input.color;
    return output;
}

fixed4 WaterFlowFragmentProgram(VertexOutput input) : SV_Target
{
	// necessary only if any instanced properties are going to be accessed in the fragment Shader.
    UNITY_SETUP_INSTANCE_ID(input);
    fixed4 col = fixed4(1.0, 0.0, 0.0, 1.0) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);


    
    
    //float flowScale0 = frac(_Speed * _Time.y + offset);
    float flowScale0 = 0.0;
#if !defined(PROCESS_ANIMATED_STEP_UV)
    float offset = tex2D(_PhaseMap, input.uv).r;
    flowScale0 = frac(_Speed * _Time.y + offset);
#endif
	//float flowScale1 = frac(_Speed * _Time.y + offset + 0.5f);
    half4 flowColor = tex2D(_FlowsMap, input.uv + flowScale0);
    float2 flowRawDir = flowColor.rg;
    flowRawDir = 2.0 * (flowRawDir.xy - float2(0.5, 0.5));
    flowRawDir *= float2(_FlowSignX, _FlowSignY);
    flowRawDir = flowRawDir * _FlowIntensity;	
	
    float alpha = /*abs(2.0f * (flowScale0 - 0.5)) **/flowColor.a * _MinRatio * UNITY_ACCESS_INSTANCED_PROP(Props, _Color).a;

    //return fixed4(flowRawDir * 0.5 + 0.5, 0.0, alpha);
    return fixed4(flowRawDir * 0.5 + 0.5, 0.0, flowColor.a * input.color.a);

    //fixed4 col = tex2D(_MainTex, input.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);

    //return col;
}




/*
//#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"

#include "UnityCG.cginc" 

struct WaterFlowVertexInput
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct WaterFlowVertexOutput
{
	float4 vertex : POSITION;
	float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

sampler2D _FlowsMap; //SAMPLER(sampler_FlowsMap); float4 _FlowsMap_ST;
sampler2D _PhaseMap; //SAMPLER(sampler_PhaseMap);
//float4 _PhaseMap_ST;

UNITY_INSTANCING_BUFFER_START(Props)	
	UNITY_DEFINE_INSTANCED_PROP(float4, _Color)
UNITY_INSTANCING_BUFFER_END(Props)

//CBUFFER_START(UnityPerMaterial)
float     _Speed;
float     _FlowIntensity;
float     _FlowSignX;
float     _FlowSignY;
//CBUFFER_END

WaterFlowVertexOutput WaterFlowVertexProgram(WaterFlowVertexInput input)
{
	WaterFlowVertexOutput output;

	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	//VertexPositionInputs vertexInput = GetVertexPositionInputs(input.vertex.xyz);
	//output.vertex = vertexInput.positionCS;
	//output.uv = TRANSFORM_TEX(input.uv, _FlowsMap);

    output.vertex = UnityObjectToClipPos(input.vertex);

    output.uv = input.uv;

	return output;
}

half4 WaterFlowFragmentProgram(WaterFlowVertexOutput input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    float offset = tex2D(_PhaseMap, input.uv).r;

	float flowScale0 = frac(_Speed * _Time.y + offset);
	//float flowScale1 = frac(_Speed * _Time.y + offset + 0.5f);

    half4 flowColor = tex2D(_FlowsMap, input.uv);
	float2 flowRawDir = flowColor.rg;
	flowRawDir = 2.0 * (flowRawDir.xy - float2(0.5, 0.5));
	flowRawDir *= float2(_FlowSignX, _FlowSignY);
	flowRawDir = flowRawDir * _FlowIntensity;

	//SAMPLE_TEXTURE2D(_FlowsMap, sampler_FlowsMap, input.uv).rg;

	//half4 color = half4(SAMPLE_TEXTURE2D(_FlowsMap, sampler_FlowsMap, input.uv).rgb, 1.0);
	//return SAMPLE_TEXTURE2D(_FlowsMap, sampler_FlowsMap, input.uv);
	//return color;

	//float alpha = abs(2.0f * (flowScale0 - 0.5)) * flowColor.a;

	//return half4(flowRawDir * 2.0 - 1, 0.0, alpha);

    //fixed4 col = tex2D(_MainTex, input.uv) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color);

    //return half4(flowRawDir * 2.0 - 1, 0.0, flowColor.a * UNITY_ACCESS_INSTANCED_PROP(Props, _Color).a);
    //return half4(1.0, 0.0, 0.0, max(UNITY_ACCESS_INSTANCED_PROP(Props, _Color).a, 0.0));
    //return half4(1.0, 0.0, 0.0, max(UNITY_ACCESS_INSTANCED_PROP(Props, _Color).a, 0.0));
    return half4(1.0, 0.0, 0.0, 1.0) * UNITY_ACCESS_INSTANCED_PROP(Props, _Color).a;
}*/
#endif//WATER_FLOWS_IMPL_INCLUDED