using UnityEngine.Rendering.Universal;

public class HandleURPRenderStepFeature : ScriptableRendererFeature
{
    public override void Create()
    {
        //m_AfterOpaquePass = new AppendColorBufferPass(RenderPassEvent.BeforeRenderingSkybox);
        m_AfterSkyPass = new AppendColorBufferPass(RenderPassEvent.AfterRenderingSkybox);
        m_AfterTransparencyPass = new AppendColorBufferPass(RenderPassEvent.AfterRenderingTransparents);
    }
    
    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        //m_AfterOpaquePass.SetTargetRenderer(renderer);
        //renderer.EnqueuePass(m_AfterOpaquePass);

        m_AfterSkyPass.SetTargetRenderer(renderer);
        renderer.EnqueuePass(m_AfterSkyPass);

        m_AfterTransparencyPass.SetTargetRenderer(renderer);
        renderer.EnqueuePass(m_AfterTransparencyPass);
    }

    private AppendColorBufferPass m_AfterOpaquePass = null;
    private AppendColorBufferPass m_AfterSkyPass = null;
    private AppendColorBufferPass m_AfterTransparencyPass = null;
}