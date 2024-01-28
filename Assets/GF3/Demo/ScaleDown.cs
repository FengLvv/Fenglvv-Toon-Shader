using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScaleDown : MonoBehaviour {
    public float ScaleTo;
    public float ScaleToSpeed;

    void FixedUpdate()
    {
        if( transform.localScale.x>ScaleTo ) {
            transform.localScale -= new Vector3( ScaleToSpeed*0.001f,ScaleToSpeed*0.001f,ScaleToSpeed*0.001f );
        }
    }
}

