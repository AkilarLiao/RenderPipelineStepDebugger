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

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_TargetScriptableRenderer == null)
            return;

        var renderTargetIdentifier = renderingData.cameraData.renderer.cameraColorTarget;
        var clearColor = this.clearColor;
        DrawDebugRenderTexturePass.Add(ref context, ref renderTargetIdentifier,
            ref clearColor, this.clearFlag);
    }

    private ScriptableRenderer m_TargetScriptableRenderer = null;
    private RenderTargetHandle m_environmentMapHandle;
}
