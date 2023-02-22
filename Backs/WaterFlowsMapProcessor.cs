//using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using MyLWRP;
using UnityEngine.Rendering.LWRP;

namespace WaterSystem
{
    public class WaterFlowsMapProcessor : IBeforeRender
    {
        public void Enable()
        {
            if (m_filterSettings.layerMask == 0)
            {
                m_filterSettings = new FilteringSettings(RenderQueueRange.transparent, ~0);
                m_shaderTagID = new ShaderTagId("WaterFlows");
            }
            BeforeRenderingPass.GetFollowControler().AddInterface(this);
            m_enable = true;
            Shader.SetGlobalTexture("_WaterFlowsRT", Texture2D.blackTexture);
        }
        public void Disable()
        {
            BeforeRenderingPass.GetFollowControler().RemoveInterface(this);
            m_enable = false;
        }
        uint IStepFollow.GetPriorityID()
        {
            return 0;
        }
        bool IStepFollow.IsEnable()
        {
            return m_enable;
        }
        void IBeforeRender.Execute(ref ScriptableRenderContext context, ref RenderingData renderingData,
            AccessRenderTarget accessInterface)
		{
            if (accessInterface == null)
                return;

            if (m_enable == false)
                return;

            if (m_waterFlowsRTHandle.id == -1)
                m_waterFlowsRTHandle.Init("_WaterFlowsRT");
            RenderTargetIdentifier waterDecalsRTIdentifier;

            CommandBuffer cmd = CommandBufferPool.Get(m_profilerTag);

            using (new ProfilingSample(cmd, m_profilerTag))
            {
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.depthBufferBits = 0;

                cmd.GetTemporaryRT(m_waterFlowsRTHandle.id, descriptor,
                    FilterMode.Bilinear);

                waterDecalsRTIdentifier = m_waterFlowsRTHandle.Identifier();
                RenderUtility.SetRenderTarget(cmd, waterDecalsRTIdentifier, ClearFlag.Color, Color.clear);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                Camera camera = renderingData.cameraData.camera;
                SortingSettings sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonTransparent };
                DrawingSettings drawSettings = new DrawingSettings(m_shaderTagID, sortingSettings)
                {
                    perObjectData = renderingData.perObjectData,
                    enableInstancing = true,
                    mainLightIndex = renderingData.lightData.mainLightIndex,
                    enableDynamicBatching = renderingData.supportsDynamicBatching,
                };

                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref m_filterSettings);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);

            DrawDebugRTsPass.AddDebugRT(ref context, ref waterDecalsRTIdentifier, renderingData.cameraData.camera.cameraType);
            
        }
        void IBeforeRender.FrameCleanup(CommandBuffer cmd)
        {
            if (m_waterFlowsRTHandle != RenderTargetHandle.CameraTarget)
            {
                cmd.ReleaseTemporaryRT(m_waterFlowsRTHandle.id);
                m_waterFlowsRTHandle = RenderTargetHandle.CameraTarget;
            }
        }
        private bool m_enable;
        private FilteringSettings m_filterSettings;
        private const string m_profilerTag = "Render WaterDecals";
        private ShaderTagId m_shaderTagID;
        private RenderTargetHandle m_waterFlowsRTHandle;
    }
}