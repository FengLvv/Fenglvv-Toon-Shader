using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlaygroundCam : MonoBehaviour {
	public Transform target; // 你要围绕旋转的目标物体
	public float rotateSpeed = 5.0f; // 控制旋转速度
	public float zoomSpeed = 2.0f; // 控制缩放速度
	public float minZoomDistance = 5.0f; // 相机到物体的最小距离
	public float maxZoomDistance = 15.0f; // 相机到物体的最大距离

	private Vector3 lastMousePosition;
	private Vector3 lastMouseMidPosition;

	void Start() {
		lastMousePosition = Input.mousePosition;
	}

	void Update() {
		// 鼠标滚轮控制相机到物体的距离
		float zoomInput = Input.GetAxis( "Mouse ScrollWheel" );
		if( zoomInput != 0 ) {
			Vector3 direction = ( target.position - transform.position ).normalized;
			float distance = Vector3.Distance( target.position, transform.position );
			distance = Mathf.Clamp( distance - zoomInput * zoomSpeed, minZoomDistance, maxZoomDistance );
			transform.position = target.position - direction * distance;
		}

		float verticalInput = Input.GetAxis( "Vertical" );
		Vector3 moveDirection = new Vector3( 0, verticalInput, 0 );
		transform.Translate( moveDirection * 01f * Time.deltaTime, Space.Self );

		if( Input.GetMouseButtonDown( 0 ) ) {
			// 鼠标左键按下记录鼠标位置
			lastMousePosition = Input.mousePosition;
		}
		if( Input.GetMouseButton( 0 ) ) {
			// 鼠标左键按住移动控制相机围绕物体旋转
			Vector3 delta = Input.mousePosition - lastMousePosition;
			transform.RotateAround( target.position, Vector3.up, delta.x * rotateSpeed * Time.deltaTime );
			transform.RotateAround( target.position, transform.right, -delta.y * rotateSpeed * Time.deltaTime );
			lastMousePosition = Input.mousePosition;
		}

		//中键按下记录鼠标位置
		if( Input.GetMouseButtonDown( 2 ) ) {
			lastMouseMidPosition = Input.mousePosition;
		}
		//中间按住，相机上下移动
		if( Input.GetMouseButton( 2 ) ) {
			Vector3 delta = Input.mousePosition - lastMouseMidPosition;
			float y = transform.position.y + new Vector3( 0, delta.y * Time.deltaTime, 0 ).y;

				transform.position += new Vector3( 0, delta.y * Time.deltaTime, 0 );
				lastMouseMidPosition = Input.mousePosition;
		
		}
	}

}