Shader "Elysia S_SkyAtmosphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always
        
        Pass
        {
            Name "ReBuild Position WS"
            
            HLSLINCLUDE
            #include_with_pragmas "SkyAtmosphere.hlsl"
            ENDHLSL
            
            HLSLPROGRAM
            #pragma vertex ReBuildPositionWSVS
            #pragma fragment ReBuildPositionWSPS
            ENDHLSL
        }

        Pass
        {
            Name "Sky Atmosphere"
            
            HLSLINCLUDE
            #include_with_pragmas "SkyAtmosphere.hlsl"
            ENDHLSL

            HLSLPROGRAM
            #pragma vertex SkyAtmosphere_VS
            #pragma fragment SkyAtmosphere_PS
            ENDHLSL
        }
    }
}
