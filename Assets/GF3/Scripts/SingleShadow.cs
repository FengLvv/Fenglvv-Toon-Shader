using Cysharp.Threading.Tasks;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
//https://zhuanlan.zhihu.com/p/612448813

public class SingleShadow : MonoBehaviour {
	public LayerMask shadowLayer;
	public int rtWidth = 512;
	public int rtHeight = 512;
	public List<GameObject> singleShadowGameObject;
	[FormerlySerializedAs( "CenterObject" )]
	public GameObject centerObject;
	Material defaultDepthMat;

	GameObject shadowCamera;
	Camera shadowCameraComponent;
	RenderTexture shadowTexture;
	Bounds bounds = new Bounds();
	Renderer[] boxes;

	void Start() {
		shadowCamera = new GameObject( "ShadowCamera" );
		shadowCameraComponent = shadowCamera.AddComponent<Camera>();
		shadowCameraComponent.orthographic = true;
		shadowCameraComponent.backgroundColor = Color.black;
		shadowCameraComponent.clearFlags = CameraClearFlags.SolidColor;
		shadowCameraComponent.cullingMask = shadowLayer;
		shadowTexture = RenderTexture.GetTemporary( rtWidth, rtHeight, 24, RenderTextureFormat.Depth );
		shadowTexture.name = "SingleShadowTexture";
		shadowCameraComponent.targetTexture = shadowTexture;
		boxes = singleShadowGameObject.SelectMany( t => t.GetComponentsInChildren<Renderer>() ).ToArray();

		Shader.SetGlobalTexture( "_LightCamTexture", shadowTexture );

		defaultDepthMat = Resources.Load<Material>( "DefaultDepthMat" );
	}


	// Update is called once per frame
	void Update() {
		SetCamParams();
	}


	void SetCamParams() {
		bounds.size = Vector3.zero;
		foreach( var box in boxes ) {
			int layer = 1 << box.gameObject.layer;
			if( box.gameObject.activeInHierarchy && ( layer & shadowLayer.value ) > 0 ) {
				bounds.Encapsulate( box.bounds );
			}
		}

		float x = bounds.extents.x;
		float y = bounds.extents.y;
		float z = bounds.extents.z;

		Vector3[] boundsVertexList = new Vector3[8];
		boundsVertexList[0] = ( new Vector3( x, y, z ) + bounds.center );
		boundsVertexList[1] = ( new Vector3( x, -y, z ) + bounds.center );
		boundsVertexList[2] = ( new Vector3( x, y, -z ) + bounds.center );
		boundsVertexList[3] = ( new Vector3( x, -y, -z ) + bounds.center );
		boundsVertexList[4] = ( new Vector3( -x, y, z ) + bounds.center );
		boundsVertexList[5] = ( new Vector3( -x, -y, z ) + bounds.center );
		boundsVertexList[6] = ( new Vector3( -x, y, -z ) + bounds.center );
		boundsVertexList[7] = ( new Vector3( -x, -y, -z ) + bounds.center );

		Vector3 pos = centerObject.transform.position;
		Vector3 lightDir = GameObject.FindObjectOfType<Light>().transform.forward;
		Vector3 maxDistance = new Vector3( bounds.extents.x, bounds.extents.y, bounds.extents.z );
		float length = maxDistance.magnitude;
		pos = bounds.center - lightDir * length;
		shadowCameraComponent.transform.position = pos;
		shadowCameraComponent.transform.rotation = Quaternion.LookRotation( lightDir );

		Vector2 xMinMax = new Vector2( int.MinValue, int.MaxValue );
		Vector2 yMinMax = new Vector2( int.MinValue, int.MaxValue );
		Vector2 zMinMax = new Vector2( int.MinValue, int.MaxValue );
		Matrix4x4 world2LightMatrix = shadowCamera.transform.worldToLocalMatrix;
		for( int i = 0; i < boundsVertexList.Length; i++ ) {
			Vector4 pointLS = world2LightMatrix * boundsVertexList[i];
			if( pointLS.x > xMinMax.x )
				xMinMax.x = pointLS.x;
			if( pointLS.x < xMinMax.y )
				xMinMax.y = pointLS.x;
			if( pointLS.y > yMinMax.x )
				yMinMax.x = pointLS.y;
			if( pointLS.y < yMinMax.y )
				yMinMax.y = pointLS.y;
			if( pointLS.z > zMinMax.x )
				zMinMax.x = pointLS.z;
			if( pointLS.z < zMinMax.y )
				zMinMax.y = pointLS.z;
		}
		shadowCameraComponent.nearClipPlane = 0.01f;
		shadowCameraComponent.farClipPlane = zMinMax.x - zMinMax.y+5;
		shadowCameraComponent.orthographicSize = ( yMinMax.x - yMinMax.y ) / 2;
		shadowCameraComponent.aspect = ( xMinMax.x - xMinMax.y ) / ( yMinMax.x - yMinMax.y );

		Matrix4x4 world2View = shadowCameraComponent.worldToCameraMatrix;
		Matrix4x4 projection = GL.GetGPUProjectionMatrix( shadowCameraComponent.projectionMatrix, false );
		var m_LightVP = projection * world2View;
		Shader.SetGlobalMatrix( "_LighCamtVP", m_LightVP );
	}
}