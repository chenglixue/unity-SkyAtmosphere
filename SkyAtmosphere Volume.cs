using System;

namespace UnityEngine.Rendering.Universal
{
    [Serializable, VolumeComponentMenuForRenderPipeline("Elysia/Sky Atmosphere", typeof(UniversalRenderPipeline))]
    public class SkyAtmosphereVolume : VolumeComponent, IPostProcessComponent
    {
        public BoolParameter enable = new BoolParameter(true);
        
        public ColorParameter m_lightColor = new ColorParameter(Color.white, true, false, true);
        public ClampedFloatParameter m_rayleighScatterCoef = new ClampedFloatParameter(1f, 0f, 10f);
        public ClampedFloatParameter m_rayleighExtinctionCoef = new ClampedFloatParameter(1f, 0f, 10f);
        public ClampedFloatParameter m_mieScatterCoef = new ClampedFloatParameter(1f, 0f, 10f);
        public ClampedFloatParameter m_mieExtinctionCoef = new ClampedFloatParameter(1f, 0f, 10f);
        public ClampedFloatParameter m_mieG = new ClampedFloatParameter(0.76f, 0f, 0.999f);
        public FloatParameter m_distanceScale = new FloatParameter(1f);
        public ClampedFloatParameter m_sampleCounts = new ClampedFloatParameter(16f, 0f, 16f);
        
        public bool IsTileCompatible() => false;
        public bool IsActive() => enable == true;
    }
}
