//#define TEST_ADD

using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DrawDebugRenderTexturePass : ScriptableRenderPass
{
    public bool ReInitialize(RenderPassEvent evt, Material blitMaterial, float displayRatio,
        uint columnCount, float stepSize)
    {
        Release();
        base.profilingSampler = new ProfilingSampler(nameof(DrawDebugRenderTexturePass));
        m_TargetBlitMaterial = blitMaterial;
        renderPassEvent = evt;
        m_DisplayRatio = displayRatio;
        m_ColumnCount = columnCount;
        m_StepSize = stepSize;
        return true;
    }
    public bool Release()
    {
        ClearRenderTextures();
        return true;
    }

    public static bool Add(ref ScriptableRenderContext context,
        ref RenderTargetIdentifier destTarget, ref Color clearColor, ClearFlag clearFalg)
    {
        if (ms_targetRenderer == null)
            return false;

        RenderTexture copyRT = RenderTexture.GetTemporary(ms_RTSize.x, ms_RTSize.y,
            0, RenderTextureFormat.ARGB32);
        CommandBuffer command = CommandBufferPool.Get("BltingToDebugRT");

        command.Blit(destTarget, copyRT);

        //restore original renderTarget
        //command.SetRenderTarget(ms_targetRenderer.cameraColorTarget,
            //ms_targetRenderer.cameraDepthTarget);

        context.ExecuteCommandBuffer(command);
        CommandBufferPool.Release(command);
        ms_DebugRTs.Add(copyRT);

        return true;
    }

    public void SetupRenderer(ScriptableRenderer targetRenderer)
    {
        ms_targetRenderer = targetRenderer;
    }

    private void ClearRenderTextures()
    {
        var element = ms_DebugRTs.GetEnumerator();
        while (element.MoveNext())
            RenderTexture.ReleaseTemporary(element.Current);
        element.Dispose();
        ms_DebugRTs.Clear();
    }
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
#if TEST_ADD
        RenderTargetIdentifier targetIdentifier = Texture2D.blackTexture;
        Add(ref context, ref targetIdentifier);

        targetIdentifier = Texture2D.whiteTexture;
        Add(ref context, ref targetIdentifier);
#endif//TEST_ADD

        if (!m_TargetBlitMaterial)
            return;

        CommandBuffer command = CommandBufferPool.Get(mc_ProfilerTag);
        using (new ProfilingScope(command, m_ProfilingSampler))
        {
            var cameraData = renderingData.cameraData;
            var camera = cameraData.camera;
            var origionViewMatrix = cameraData.GetViewMatrix();
            var origionProjectionMatrix = camera.projectionMatrix;

            command.SetViewProjectionMatrices(Matrix4x4.identity, Matrix4x4.identity);
            Vector2 RectSize = new Vector2(camera.pixelRect.width * m_DisplayRatio,
                camera.pixelRect.height * m_DisplayRatio);
            Rect displayRect = new Rect(0.0f, 0.0f, RectSize.x, RectSize.y);

            uint index = 0;
            uint columnIndex, rowIndex;
            var element = ms_DebugRTs.GetEnumerator();
            while (element.MoveNext())
            {
                rowIndex = index / m_ColumnCount;
                columnIndex = index % m_ColumnCount;
                displayRect.x = (RectSize.x + m_StepSize) * columnIndex;
                displayRect.y = camera.pixelRect.height - ((RectSize.y + m_StepSize) *
                    rowIndex + RectSize.y);
                command.SetViewport(displayRect);
                command.SetGlobalTexture("_SourceTex", element.Current);
                command.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity,
                    m_TargetBlitMaterial);
                ++index;
            }
            element.Dispose();

            //restore
            command.SetViewProjectionMatrices(origionViewMatrix, origionProjectionMatrix);
        }
        context.ExecuteCommandBuffer(command);
        CommandBufferPool.Release(command);

        ClearRenderTextures();
    }

    public override void FrameCleanup(CommandBuffer cmd)
    {
        ClearRenderTextures();
    }

    private static List<RenderTexture> ms_DebugRTs = new List<RenderTexture>();
    private static Vector2Int ms_RTSize = new Vector2Int(256, 256);

    private float m_DisplayRatio = 0.3f;
    private uint m_ColumnCount = 6;
    private float m_StepSize = 10.0f;

    private Material m_TargetBlitMaterial = null;    
    private const string mc_ProfilerTag = "DrawDebugRenderTexturePass";    
    private ProfilingSampler m_ProfilingSampler = new ProfilingSampler(mc_ProfilerTag);
    private static ScriptableRenderer ms_targetRenderer = null;
}
