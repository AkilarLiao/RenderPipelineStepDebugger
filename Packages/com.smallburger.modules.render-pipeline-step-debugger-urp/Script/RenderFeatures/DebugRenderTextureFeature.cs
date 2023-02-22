using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DebugRenderTextureFeature : ScriptableRendererFeature
{
    public override void Create()
    {
#if UNITY_EDITOR
        ResourceReloader.ReloadAllNullIn(this, UniversalRenderPipelineAsset.packagePath);
#endif
        m_BlitMaterial = CoreUtils.CreateEngineMaterial(m_Shaders.m_BltPS);
        m_DrawDebugRenderTexturePass.ReInitialize(RenderPassEvent.AfterRendering + 2, m_BlitMaterial, m_DisplayRatio,
            m_ColumnCount, m_StepSize);
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

    [SerializeField]
    [Range(0.1f, 0.5f)]
    private float m_DisplayRatio = 0.3f;

    [SerializeField]
    [Range(1, 6)]
    private uint m_ColumnCount = 3;

    [SerializeField]
    [Range(1.0f, 20.0f)]
    private const float m_StepSize = 10.0f;

    [HideInInspector]
    [SerializeField]
    private ShaderResources m_Shaders = null;

    private Material m_BlitMaterial = null;
    private DrawDebugRenderTexturePass m_DrawDebugRenderTexturePass = new DrawDebugRenderTexturePass();
}