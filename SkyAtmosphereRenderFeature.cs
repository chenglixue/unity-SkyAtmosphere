namespace UnityEngine.Rendering.Universal
{
    public class SkyAtmosphereRenderFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class SkyAtmosphereSetting
        {
            public string m_profilerTags = "Sky Aomosphere Pass";
            public Shader m_shader;
            public ComputeShader m_computeShader;
            public RenderPassEvent m_passEvent = RenderPassEvent.BeforeRenderingTransparents;
        }
        SkyAtmosphereRenderPass m_skyAomospherePass;
        public SkyAtmosphereSetting m_passSetting = new SkyAtmosphereSetting();
        
        public override void Create()
        {
            m_skyAomospherePass = new SkyAtmosphereRenderPass(m_passSetting);
        }
        
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var volume = VolumeManager.instance.stack.GetComponent<SkyAtmosphereVolume>();

            if (volume != null && volume.IsActive() == true)
            {
                m_skyAomospherePass.Setup(volume);
                
                renderer.EnqueuePass(m_skyAomospherePass);
            }
        }
    }   
}


