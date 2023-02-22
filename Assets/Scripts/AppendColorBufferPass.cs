using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AppendColorBufferPass : ScriptableRenderPass
{
    public AppendColorBufferPass(RenderPassEvent renderPassEvent)
    {
        this.renderPassEvent = renderPassEvent;

        m_environmentMapHandle.Init("_EnvironmentMap");
    }

    public void SetTargetRenderer(ScriptableRenderer renderer)
    {
        m_TargetScriptableRenderer = renderer;
    }

    //public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    //{

    //}

    //public override void OnCameraSetup(CommandBuffer commandBuffer, ref RenderingData renderingData)
    //{
    //    ConfigureTarget(m_TargetScriptableRenderer.cameraColorTarget, m_TargetScriptableRenderer.cameraDepthTarget);
    //    ConfigureClear(ClearFlag.None, Color.clear);
    //}

    public override void OnCameraSetup(CommandBuffer commandBuffer,
            ref RenderingData renderingData)
    {
        var cameraData = renderingData.cameraData;        
        RenderTextureDescriptor descriptor =
            cameraData.cameraTargetDescriptor;
        descriptor.depthBufferBits = 0;

        descriptor.colorFormat = SystemInfo.SupportsRenderTextureFormat(
            RenderTextureFormat.RG16) ?
            RenderTextureFormat.RG16 : RenderTextureFormat.ARGB32;

        commandBuffer.GetTemporaryRT(m_environmentMapHandle.id,
            descriptor);
        ConfigureTarget(m_environmentMapHandle.Identifier(),
            cameraData.renderer.cameraDepthTarget);
        ConfigureClear(ClearFlag.Color, Color.clear);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_TargetScriptableRenderer == null)
            return;

        var renderTargetIdentifier = renderingData.cameraData.renderer.cameraColorTarget;
        var clearColor = this.clearColor;
        DrawDebugRenderTexturePass.Add(ref context, ref renderTargetIdentifier,
            ref clearColor, this.clearFlag);

        //var value = renderingData.cameraData.renderer.cameraColorTarget;

        //this.clearColor
        //this.clearFlag

        //ScriptableRenderer.SetRenderTarget(cmd, opaqueColorRT, BuiltinRenderTextureType.CameraTarget, clearFlag,
        //    clearColor);

        //RenderBufferLoadAction colorLoadAction = RenderBufferLoadAction.Load,
        //RenderBufferStoreAction colorStoreAction = RenderBufferStoreAction.Store,
        //RenderBufferLoadAction depthLoadAction = RenderBufferLoadAction.Load,
        //RenderBufferStoreAction depthStoreAction = RenderBufferStoreAction.Store

        //cmd.SetRenderTarget(destination, colorLoadAction, colorStoreAction, depthLoadAction, depthStoreAction);
        //cmd.Blit(source, BuiltinRenderTextureType.CurrentActive, material, passIndex);
    }

    public override void OnCameraCleanup(CommandBuffer command)
    {
        
        {
            command.ReleaseTemporaryRT(m_environmentMapHandle.id);
        }
    }

    private ScriptableRenderer m_TargetScriptableRenderer = null;

    private RenderTargetHandle m_environmentMapHandle;
}
