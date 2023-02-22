Shader "CustomLightweight/WaterParticleFlows"
{
	Properties
	{
		_FlowsMap("FlowsMap", 2D) = "white" {}
		_PhaseMap("PhaseMap(R)", 2D) = "black" {}
		_Speed("Speed", Range(0.0, 1.0)) = 0.4
		_FlowIntensity("FlowIntensity", Range(0.0, 1.0)) = 0.25
		_FlowSignX("FlowSignX", Range(-1.0, 1.0)) = 1.0
		_FlowSignY("FlowSignY", Range(-1.0, 1.0)) = -1.0
		_MinRatio("MinRatio", Range(1.0, 10.0)) = 1.0
	}
	SubShader
	{
		LOD 100
		Tags
		{
			"Queue" = "Transparent"
			"RenderType" = "Transparent"
			"IgnoreProjector" = "True"
		}
		Pass
		{
			Tags {"LightMode" = "WaterFlows"}

			//BlendOp Min | Max | Sub | RevSub
			//BlendOp Max

			Blend SrcAlpha OneMinusSrcAlpha // Traditional transparency, Alpha 混合
			//Blend One One // Additive, 相加
			//Blend OneMinusDstColor One   //Soft Additive, 柔和相加
			//Blend DstColor Zero         //Multiplicative, 相乘
			//Blend DstColor SrcColor     //2x Multiplicative, 2 倍相乘

			ZWrite Off
			ZTest Off
			CGPROGRAM
			#pragma vertex WaterFlowVertexProgram
			#pragma fragment WaterFlowFragmentProgram
			#pragma multi_compile_instancing
			#include "WaterParticleFlowsImpl.hlsl"
			ENDCG
		}
	}
    /*Properties
    {
		_FlowsMap("FlowsMap", 2D) = "white" {}
		_PhaseMap("PhaseMap(R)", 2D) = "black" {}
		_Color("Color", Color) = (1, 1, 1, 1)
		_Speed("Speed", Range(0.0, 1.0)) = 0.4
		_FlowIntensity("FlowIntensity", Range(0.0, 1.0)) = 0.25
		_FlowSignX("FlowSignX", Range(-1.0, 1.0)) = 1.0
		_FlowSignY("FlowSignY", Range(-1.0, 1.0)) = -1.0
    }

    SubShader
    {
        Tags{"Queue" = "Transparent"
			"RenderType" = "Transparent"
			"IgnoreProjector" = "True"}
        
        // ------------------------------------------------------------------
        //  Forward pass.
        Pass
        {
            // Lightmode matches the ShaderPassName set in LightweightRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Lightweight Render Pipeline
            Name "ForwardLit"
            Tags {"LightMode" = "WaterFlows"}
            
            //ColorMask RGB
			//Blend OneMinusDstColor One
			Blend SrcAlpha OneMinusSrcAlpha
			ZWrite Off
			ZTest Off
            
			CGPROGRAM
            // Required to compile gles 2.0 with standard SRP library
            // All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
            //#pragma prefer_hlslcc gles
            //#pragma exclude_renderers d3d11_9x
            //#pragma target 2.0

			#pragma multi_compile_instancing

            #pragma vertex WaterFlowVertexProgram
            #pragma fragment WaterFlowFragmentProgram
			#include "WaterFlowsImpl.hlsl"
            
			ENDCG
        }
    }*/
}
