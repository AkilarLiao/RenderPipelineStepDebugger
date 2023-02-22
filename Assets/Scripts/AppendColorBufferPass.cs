using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AppendColorBufferPass : ScriptableRenderPass
{
    public AppendColorBufferPass(RenderPassEvent renderPassEvent)
    {
        this.renderPassEvent = renderPassEvent;
    }

    public void SetTargetRenderer(ScriptableRenderer renderer)
    {
        m_TargetScriptableRenderer = renderer;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_TargetScriptableRenderer == null)
            return;
        var renderTargetIdentifier = m_TargetScriptableRenderer.cameraColorTarget;
        DrawDebugRenderTexturePass.Add(ref context, ref renderTargetIdentifier);
    }

    private ScriptableRenderer m_TargetScriptableRenderer = null;
}
