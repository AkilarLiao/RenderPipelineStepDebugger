using UnityEngine.Rendering.Universal;

public class HandleURPRenderStepFeature : ScriptableRendererFeature
{
    public override void Create()
    {
        m_AfterSkyPass = new AppendColorBufferPass(RenderPassEvent.AfterRenderingSkybox);
        m_AfterTransparencyPass = new AppendColorBufferPass(RenderPassEvent.AfterRenderingTransparents);
        m_AfterPostProcessingPass = new AppendColorBufferPass(RenderPassEvent.AfterRenderingPostProcessing);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        m_AfterSkyPass.SetTargetRenderer(renderer);
        renderer.EnqueuePass(m_AfterSkyPass);

        m_AfterTransparencyPass.SetTargetRenderer(renderer);
        renderer.EnqueuePass(m_AfterTransparencyPass);

        m_AfterPostProcessingPass.SetTargetRenderer(renderer);
        renderer.EnqueuePass(m_AfterPostProcessingPass);
    }
    private AppendColorBufferPass m_AfterSkyPass = null;
    private AppendColorBufferPass m_AfterTransparencyPass = null;
    private AppendColorBufferPass m_AfterPostProcessingPass = null;
}