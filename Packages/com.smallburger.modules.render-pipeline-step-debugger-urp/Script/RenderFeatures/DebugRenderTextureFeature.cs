using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DebugRenderTextureFeature : ScriptableRendererFeature
{
    public override void Create()
    {
#if UNITY_EDITOR
        //ResourceReloader.ReloadAllNullIn(this,
        //MobilePipeline.c_packagePath);
        ResourceReloader.ReloadAllNullIn(this,
            UniversalRenderPipelineAsset.packagePath);
#endif
        m_BlitMaterial = CoreUtils.CreateEngineMaterial(m_Shaders.m_BltPS);
        m_DrawDebugRenderTexturePass.ReInitialize(
            RenderPassEvent.AfterRendering + 2, m_BlitMaterial);
    }

    protected override void Dispose(bool disposing)
    {
        m_DrawDebugRenderTexturePass.Release();

        CoreUtils.Destroy(m_BlitMaterial);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (m_DrawDebugRenderTexturePass != null)
        {
            m_DrawDebugRenderTexturePass.SetupRenderer(renderer);
            renderer.EnqueuePass(m_DrawDebugRenderTexturePass);
        }
    }

    [System.Serializable, ReloadGroup]
    public sealed class ShaderResources
    {
        [Reload("Shaders/Utils/Blit.shader")]
        public Shader m_BltPS = null;
    }
    public ShaderResources m_Shaders = null;

    private Material m_BlitMaterial = null;
    private DrawDebugRenderTexturePass m_DrawDebugRenderTexturePass = new DrawDebugRenderTexturePass();
    public static readonly string c_packagePath =
        "Packages/com.igg.mobile-urp";
}