using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraController : MonoBehaviour
{
    // Camera orbit parameters]
    private bool rotating = false;
    public float orbitSpeed = 1;
    private Vector3 lastMousePosition = Vector3.zero;
    private Vector3 lastLocalEulerAngles = Vector3.zero;

    // Camera move parameters
    private bool moving = true;
    public float moveSpeed = 1;
    private Vector3 moveDir = Vector3.zero;

    // Update is called once per frame
    void Update()
    {
        if (!rotating)
        {
            if (Input.GetMouseButtonDown(0))
            {
                rotating = true;
                lastLocalEulerAngles = transform.eulerAngles;
                lastMousePosition = Input.mousePosition;
            }
        }

        if (rotating)
        {
            if (Input.GetMouseButtonUp(0))
            {
                rotating = false;
            }
            {
                // Use mouseDelta to rotate camera
                Vector3 mouseDelta = Input.mousePosition - lastMousePosition;
                Vector3 eulerAnglesOffset = new Vector3(mouseDelta.y, -mouseDelta.x, 0);
                transform.eulerAngles = lastLocalEulerAngles + orbitSpeed * eulerAnglesOffset;
            }
        }

        if (moving)
        {
            if (Input.GetKey(KeyCode.W))
            {
                moveDir = transform.forward;
            }
            else if (Input.GetKey(KeyCode.S))
            {
                moveDir = -transform.forward;
            }
            else if (Input.GetKey(KeyCode.D))
            {
                moveDir = transform.right;
            }
            else if (Input.GetKey(KeyCode.A))
            {
                moveDir = -transform.right;
            }
            else
            {
                moveDir = Vector3.zero;
            }

            moveDir = Vector3.ProjectOnPlane(moveDir, Vector3.up);

            transform.position += moveSpeed * Time.deltaTime * moveDir;
        }
    }
}
