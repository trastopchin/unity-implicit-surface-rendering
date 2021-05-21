using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ImplicitSurfaceController : MonoBehaviour
{
    public CameraController cameraController;
    public float interactDistance;

    private Material material;

    public float paramSpeed = 1;
    public float param1LowerBound = 0;
    public float param1UpperBound = 1;

    private void Start()
    {
        material = GetComponent<MeshRenderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        if ((transform.position - cameraController.transform.position).magnitude <= interactDistance)
        {
            if (Input.GetKey(KeyCode.Q))
            {
                float param1 = material.GetFloat("_Param1") - paramSpeed * (param1LowerBound - param1UpperBound) * Time.deltaTime;
                material.SetFloat("_Param1", Mathf.Clamp(param1, param1LowerBound, param1UpperBound));
            }
            else if (Input.GetKey(KeyCode.E))
            {
                float param1 = material.GetFloat("_Param1") + paramSpeed * (param1LowerBound - param1UpperBound) * Time.deltaTime;
                material.SetFloat("_Param1", Mathf.Clamp(param1, param1LowerBound, param1UpperBound));
            }

        }
    }
}
