using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DrawFringeFeature : ScriptableRendererFeature {

	[System.Serializable]
	public class Setting {
		public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;
		public string FringeTagName = "Fringe";
		public LayerMask FringeLayer;
		public string BrowTagName = "Brow";
		public LayerMask BrowLayer;
		public LayerMask OutlineLayer;
		public Shader outlineShader;
		[Range( 0, 0.01f )]
		public float outlineWidth = 0.01f;
		public LayerMask InlineLayer;
		public Shader inlineShader;
		[Range( 0, 0.1f )]
		public float inlineWidth = 0.1f;

	}
	public Setting setting = new Setting();
	class CustomRenderPass : ScriptableRenderPass {
		RTHandle _cameraDepthTexture;
		RTHandle _cameraColorTexture;
		ShaderTagId shaderTagFringe;
		ShaderTagId shaderTagBrow;
		ShaderTagId shaderTagLine;


		public Setting setting;


		RenderTextureDescriptor m_Descriptor;
		public CustomRenderPass( Setting setting ) {
			this.setting = setting;
			shaderTagFringe = new ShaderTagId( setting.FringeTagName );
			shaderTagBrow = new ShaderTagId( setting.BrowTagName );
			shaderTagLine = new ShaderTagId( "UniversalForward" );
		}

		public override void Execute( ScriptableRenderContext context, ref RenderingData renderingData ) {
			//新建filter,只渲染人物层
			RenderQueueRange queue = new RenderQueueRange();
			queue.lowerBound = RenderQueueRange.opaque.lowerBound;
			queue.upperBound = RenderQueueRange.opaque.upperBound;
			DrawingSettings drawFringe = CreateDrawingSettings( shaderTagFringe, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags );
			FilteringSettings filteringFringe = new FilteringSettings( queue, setting.FringeLayer );

			DrawingSettings drawBrow = CreateDrawingSettings( shaderTagBrow, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags );
			FilteringSettings filteringBrow = new FilteringSettings( queue, setting.BrowLayer );

			Shader.SetGlobalFloat( OutlineWidth, setting.outlineWidth );
			DrawingSettings drawOutline = CreateDrawingSettings( shaderTagLine, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags );
			drawOutline.overrideShader = setting.outlineShader;
			FilteringSettings filteringOutline = new FilteringSettings( queue, setting.OutlineLayer );

			Shader.SetGlobalFloat( InlineWidth, setting.inlineWidth );
			DrawingSettings drawInline = CreateDrawingSettings( shaderTagLine, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags );
			drawInline.overrideShader = setting.inlineShader;
			FilteringSettings filteringInline = new FilteringSettings( queue, setting.InlineLayer );


			context.DrawRenderers( renderingData.cullResults, ref drawInline, ref filteringInline );
			context.DrawRenderers( renderingData.cullResults, ref drawOutline, ref filteringOutline );
			context.DrawRenderers( renderingData.cullResults, ref drawFringe, ref filteringFringe );
			context.DrawRenderers( renderingData.cullResults, ref drawBrow, ref filteringBrow );

		}

		public override void FrameCleanup( CommandBuffer cmd ) {

		}
	}

	CustomRenderPass m_ScriptablePass;
	readonly static int OutlineWidth = Shader.PropertyToID( "_OutlineWidth" );
	readonly static int InlineWidth = Shader.PropertyToID( "_InlineWidth" );

	public override void Create() {
		m_ScriptablePass = new CustomRenderPass( setting );
		m_ScriptablePass.renderPassEvent = setting.passEvent;
	}
	public override void SetupRenderPasses( ScriptableRenderer renderer, in RenderingData renderingData ) {
		if( renderingData.cameraData.cameraType == CameraType.Game ) {
			//声明要使用的颜色和深度缓冲区
			m_ScriptablePass.ConfigureInput( ScriptableRenderPassInput.Depth );
			m_ScriptablePass.ConfigureInput( ScriptableRenderPassInput.Color );
		}
	}
	public override void AddRenderPasses( ScriptableRenderer renderer, ref RenderingData renderingData ) {
		renderer.EnqueuePass( m_ScriptablePass );
	}
}