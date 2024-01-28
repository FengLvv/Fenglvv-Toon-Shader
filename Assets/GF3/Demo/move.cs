using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class move : MonoBehaviour {
	public bool isMove = false;
	public bool isRotate = false;
	// Start is called before the first frame update
	void Start() {

	}
	public float moveSpeed = 2.0f;

	void FixedUpdate() {
		if( isMove ) {
			transform.Translate( Vector3.forward * ( 0.003f * ( Mathf.Sin( moveSpeed * Time.fixedTime ) ) ) );

		}
		if( isRotate ) {
			transform.RotateAround( transform.position,Vector3.up,moveSpeed );
		}
	}

}