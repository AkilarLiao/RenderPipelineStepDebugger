using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class AppendColorBufferPass : ScriptableRenderPass
{
    public AppendColorBufferPass(RenderPassEvent renderPassEvent)
    {
        this.renderPassEvent = renderPassEvent;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        var renderTargetIdentifier = renderingData.cameraData.renderer.cameraColorTarget;
        var clearColor = this.clearColor;
        DrawDebugRenderTexturePass.Add(ref context, ref renderTargetIdentifier);
    }
}
