using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// A simple script that allows the player to change the parameters defining
/// implicit surfaces.
/// </summary>
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

    /// <summary>
    /// When the player is less than interactDistance distance away from an
    /// implicit surface they can use the Q and E keys to decrease and increase
    /// the _Param1 material property, respectively.
    /// </summary>
    void Update()
    {
        // If the player is close enough
        if ((transform.position - cameraController.transform.position).magnitude <= interactDistance)
        {
            // Decrease or increase the _Param1 material property
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
