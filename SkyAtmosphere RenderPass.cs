using System.Collections.Generic;
using Unity.VisualScripting;

namespace UnityEngine.Rendering.Universal
{
    class SkyAtmosphereRenderPass : ScriptableRenderPass
    {
        #region Variable
        private SkyAtmosphereRenderFeature.SkyAtmosphereSetting m_skyAtmospherePassSetting;
        private SkyAtmosphereVolume m_skyAtmosphereVolume;
        private Shader m_shader;
        private ComputeShader m_computeShader;
        private Material m_material;

        private ProfilingSampler m_profilingSampler;
        private RenderTextureDescriptor m_descriptorRT;
        private RenderTargetIdentifier m_cameraRT;
        private int m_skyAtmosphereID = Shader.PropertyToID("Sky_Atmosphere_RT");
        private int m_sourceRTID = Shader.PropertyToID("_Source_RT");
        private Vector4 m_RTSize;
        #endregion

        #region Setup
        public SkyAtmosphereRenderPass(SkyAtmosphereRenderFeature.SkyAtmosphereSetting skyAomospherePassSetting)
        {
            m_skyAtmospherePassSetting = skyAomospherePassSetting;

            renderPassEvent = m_skyAtmospherePassSetting.m_passEvent;
            m_profilingSampler = new ProfilingSampler(m_skyAtmospherePassSetting.m_profilerTags);
            m_shader = m_skyAtmospherePassSetting.m_shader;
            m_computeShader = m_skyAtmospherePassSetting.m_computeShader;

            if (m_shader != null)
            {
                m_material = new Material(m_shader);
            }
            else
            {
                Debug.LogError("Sky Atmosphere Pass's shader is missing!");
            }
        }

        public void Setup(SkyAtmosphereVolume skyAtmosphereVolume)
        {
            m_skyAtmosphereVolume = skyAtmosphereVolume;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            m_descriptorRT = renderingData.cameraData.cameraTargetDescriptor;
            m_descriptorRT.msaaSamples = 1;
            m_descriptorRT.depthBufferBits = 0;
            m_descriptorRT.enableRandomWrite = true;

            m_cameraRT = renderingData.cameraData.renderer.cameraColorTarget;
        }

        Vector4 GetRTSize(int width, int height)
        {
            return new Vector4(width, height, 1f / width, 1f / height);
        }
        #endregion
        
        #region Execute
        void SetSkyAtmosphereParas(Material material, SkyAtmosphereVolume skyAtmosphereVolume, Vector4 RTSize)
        {
            const float atmosphereHeight = 80000.0f;
            const float planetRadius = 6371000.0f;
            Vector4 densityScale = new Vector4(8500.0f, 1200.0f, 0, 0);
            Vector4 scatteringR = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f;
            Vector4 scatteringM = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;
            
            material.SetVector("_MainLightDir", RenderSettings.sun.transform.rotation * Vector3.forward);
            material.SetVector("_RTSize", RTSize);
            material.SetFloat("_SkyAtmosphereHeight", atmosphereHeight);
            material.SetFloat("_PlanetRadius", planetRadius);
            material.SetFloat("_SeaLevelHeight_R", densityScale.x);
            material.SetFloat("_SeaLevelHeight_M", densityScale.y);
            material.SetVector("_Scattering_R", scatteringR * skyAtmosphereVolume.m_rayleighScatterCoef.value);
            material.SetVector("_Scattering_M", skyAtmosphereVolume.m_mieScatterCoef.value * scatteringM);
            material.SetVector("_Extinction_R", scatteringR * skyAtmosphereVolume.m_rayleighExtinctionCoef.value);
            material.SetVector("_Extinction_M", scatteringM * skyAtmosphereVolume.m_mieExtinctionCoef.value);
            material.SetVector("_LightColor", skyAtmosphereVolume.m_lightColor.value);
            material.SetFloat("_MieG", skyAtmosphereVolume.m_mieG.value);
            material.SetFloat("_DistanceScale", skyAtmosphereVolume.m_distanceScale.value);
            material.SetFloat("_SampleCounts", skyAtmosphereVolume.m_sampleCounts.value);
        }
        
        void DoSkyAtmosphere(CommandBuffer cmd, RenderTargetIdentifier sourceRT, RenderTargetIdentifier targetRT, Material material, Vector4 RTSize)
        {
            SetSkyAtmosphereParas(m_material, m_skyAtmosphereVolume, RTSize);
            
            cmd.Blit(sourceRT, targetRT, material, 1);
        }
        
        void DoSkyAtmosphere(CommandBuffer cmd, RenderTargetIdentifier sourceRT, RenderTargetIdentifier targetRT, ComputeShader computeShader, Vector4 RTSize)
        {
            string kernelName = "ComputeSkyAtmosphere";
            int kernelIndex = computeShader.FindKernel(kernelName);
            computeShader.GetKernelThreadGroupSizes(kernelIndex, out uint x, out uint y, out uint z);
            
            const float atmosphereHeight = 80000.0f;
            const float planetRadius = 6371000.0f;
            Vector4 densityScale = new Vector4(7994.0f, 1200.0f, 0, 0);
            Vector4 scatteringR = new Vector4(5.8f, 13.5f, 33.1f, 0.0f) * 0.000001f;
            Vector4 scatteringM = new Vector4(2.0f, 2.0f, 2.0f, 0.0f) * 0.00001f;
            
            cmd.SetComputeVectorParam(computeShader, "_MainLightDir", RenderSettings.sun.transform.rotation * Vector3.forward);
            cmd.SetComputeVectorParam(computeShader, "_RTSize", RTSize);
            cmd.SetComputeVectorParam(computeShader, "_Scattering_R", scatteringR * m_skyAtmosphereVolume.m_rayleighScatterCoef.value);
            cmd.SetComputeVectorParam(computeShader, "_Scattering_M", m_skyAtmosphereVolume.m_mieScatterCoef.value * scatteringM);
            cmd.SetComputeVectorParam(computeShader, "_Extinction_R", scatteringR * m_skyAtmosphereVolume.m_rayleighExtinctionCoef.value);
            cmd.SetComputeVectorParam(computeShader, "_Extinction_M", scatteringM * m_skyAtmosphereVolume.m_mieExtinctionCoef.value);
            cmd.SetComputeVectorParam(computeShader, "_LightColor", m_skyAtmosphereVolume.m_lightColor.value);
            cmd.SetComputeFloatParam(computeShader, "_SkyAtmosphereHeight", atmosphereHeight);
            cmd.SetComputeFloatParam(computeShader, "_PlanetRadius", planetRadius);
            cmd.SetComputeFloatParam(computeShader, "_SeaLevelHeight_R", densityScale.x);
            cmd.SetComputeFloatParam(computeShader, "_SeaLevelHeight_M", densityScale.y);
            cmd.SetComputeFloatParam(computeShader, "_MieG", m_skyAtmosphereVolume.m_mieG.value);
            cmd.SetComputeFloatParam(computeShader, "_DistanceScale", m_skyAtmosphereVolume.m_distanceScale.value);
            cmd.SetComputeFloatParam(computeShader, "_SampleCounts", m_skyAtmosphereVolume.m_sampleCounts.value);
            cmd.SetComputeTextureParam(computeShader, kernelIndex, "_Source_RT", sourceRT);
            cmd.SetComputeTextureParam(computeShader, kernelIndex, "_Result_RT", targetRT);
            
            cmd.DispatchCompute(computeShader, kernelIndex, (int)(RTSize.x / x), (int)(RTSize.y / y), 1);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get();
            
            using(new ProfilingScope(cmd, m_profilingSampler))
            {
                cmd.GetTemporaryRT(m_skyAtmosphereID, m_descriptorRT);
                cmd.GetTemporaryRT(m_sourceRTID, m_descriptorRT);
                
                cmd.Blit(m_cameraRT, m_sourceRTID);
                
                m_RTSize = GetRTSize(m_descriptorRT.width, m_descriptorRT.height);
                DoSkyAtmosphere(cmd, m_cameraRT, m_skyAtmosphereID, m_material, m_RTSize);
                //DoSkyAtmosphere(cmd, m_cameraRT, m_skyAtmosphereID, m_computeShader, m_RTSize);
                
                cmd.Blit(m_skyAtmosphereID, m_cameraRT);
            }
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_skyAtmosphereID);
            cmd.ReleaseTemporaryRT(m_sourceRTID);
        }
        #endregion
    }
   
}