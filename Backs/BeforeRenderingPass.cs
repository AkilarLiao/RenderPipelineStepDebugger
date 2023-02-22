using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.LWRP;

namespace MyLWRP
{
    public interface IBeforeRender : IStepFollow
    {   
        void Execute(ref ScriptableRenderContext context, ref RenderingData renderingData, AccessRenderTarget accessInterface);
        void FrameCleanup(CommandBuffer cmd);
    }

    public class BeforeRenderingPass : ScriptableRenderPass
    {
        public static bool EnableBeforeRender
        {
            get { return _processBeforeRender; }
            set { _processBeforeRender = value; }
        }
        public static StepFollowControler GetFollowControler() { return _stepFollowControler; }

        public BeforeRenderingPass(AccessRenderTarget accessInterface)
        {
            //renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

            renderPassEvent = RenderPassEvent.BeforeRenderingPrepasses;
            //renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
            //renderPassEvent = RenderPassEvent.BeforeRendering;

            m_accessInterface = accessInterface;
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_processBeforeRender)
            {
                var element = _stepFollowControler.GetInterfaces().GetEnumerator();
                while (element.MoveNext())
                {
                    if (element.Current.IsEnable())
                        ((IBeforeRender)element.Current).Execute(ref context, ref renderingData, m_accessInterface);
                }
                element.Dispose();
            }
        }
        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (cmd == null)
                throw new ArgumentNullException("cmd");

            if (_processBeforeRender)
            {
                var element = _stepFollowControler.GetInterfaces().GetEnumerator();
                while (element.MoveNext())
                {
                    if (element.Current.IsEnable())
                        ((IBeforeRender)element.Current).FrameCleanup(cmd);
                }
                element.Dispose();
            }
        }
        private static bool _processBeforeRender = true;
        private static StepFollowControler _stepFollowControler = new StepFollowControler();
        private AccessRenderTarget m_accessInterface = null;
    }
}