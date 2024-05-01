using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteAlways]
public class EyeAnchor : MonoBehaviour
{
    public Transform eye;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalVector( "_eyePos", eye.position );
        Shader.SetGlobalVector( "_eyeDir", transform.forward );
    }
}
