using System.Collections;
using System.Collections.Generic;
using UnityEngine;

using UnityEditor;
using System.IO;
using System.Text;

/// <summary>
/// An editor window that allows users to create, edit, and apply implicit surface shaders.
/// </summary>
public class ImplicitSurfacesEditor : EditorWindow
{
    // Header string we use to mark shaders we manage i.e. create / delete
    private string managedMarked = "////ManagedImplicitSurface";

    // Shader component blueprints
    public Object ISShaderBlueprint;
    public Object ISLightingBlueprint;
    public Object ISShadowsBlueprint;
    public Object ISRenderingBlueprint;

    // The new shader name
    private string shaderNameField = "";
    // The new shader's implicitSurfaceFunction
    private string implicitSurfaceFunctionField = "";

    // Whether or not we apply the shader to the selected material
    public bool applyToSelected;
    // Whether or not we delete the previous shader (if it's marked as managed)
    public bool deletePrevious;

    // Space size for the editor window
    private float mySpace = 10;

    /// <summary>
    /// Adds the custom editor window to the "Window/Rendering."
    /// </summary>
    [MenuItem("Window/Rendering/Implicit Surfaces")]
    public static void CustomEditorWindow()
    {
        GetWindow<ImplicitSurfacesEditor>("Implicit Surfaces");
    }

    /// <summary>
    /// Custom editor GUI implementation.
    /// </summary>
    private void OnGUI()
    {
        HeaderGUI();
        if (!ShaderBlueprintsGUI()) return;
        EditImplicitSurfaceGUI();
        Repaint();
    }

    /// <summary>
    /// Creates a horizontal bar.
    /// </summary>
    /// <remarks>https://answers.unity.com/questions/216584/horizontal-line.html</remarks>
    private void HorizontalBar()
    {
        EditorGUILayout.LabelField("", UnityEngine.GUI.skin.horizontalSlider);
    }

    /// <summary>
    /// The GUI header.
    /// </summary>
    private void HeaderGUI()
    {
        GUILayout.Space(mySpace);
        GUILayout.Label("Implicit Surfaces Editor", EditorStyles.boldLabel);
        HorizontalBar();
    }
    
    /// <summary>
    /// Allows users to specify the shader blueprint components.
    /// </summary>
    /// <returns>Whether or not the specified shader blueprints were set.</returns>
    private bool ShaderBlueprintsGUI()
    {
        GUILayout.Label("Shader Blueprints", EditorStyles.boldLabel);
        GUILayout.Space(mySpace);

        bool gotAllBlueprints = true;

        gotAllBlueprints &= ShaderBlueprintGUI("ISShader Blueprint", ref ISShaderBlueprint, typeof(Shader));

        gotAllBlueprints &= ShaderBlueprintGUI("ISLighting Blueprint", ref ISLightingBlueprint, typeof(object));

        gotAllBlueprints &= ShaderBlueprintGUI("ISShadows Blueprint", ref ISShadowsBlueprint, typeof(object));

        gotAllBlueprints &= ShaderBlueprintGUI("ISRendering Blueprint", ref ISRenderingBlueprint, typeof(object));

        HorizontalBar();

        return gotAllBlueprints;
    }

    /// <summary>
    /// Allows users to specify a shader blueprint component. Indicates whether or not the specified shader blueprint component is not set.
    /// </summary>
    /// <param name="name">The name of the shader blueprint.</param>
    /// <param name="shaderBlueprint">The shader blueprint we are reading.</param>
    /// <param name="type">The type specified to EditorGUILayout.ObjectField.</param>
    /// <returns>Whether or not the specified shader blueprint was set.</returns>
    private bool ShaderBlueprintGUI(string name, ref Object shaderBlueprint, System.Type type)
    {
        GUILayout.BeginHorizontal();
        GUILayout.Label(name); ;
        shaderBlueprint = EditorGUILayout.ObjectField(shaderBlueprint, type, true);
        GUILayout.EndHorizontal();

        if (shaderBlueprint == null)
        {
            GUILayout.Label("Missing " + name + "shader blueprint!", EditorStyles.whiteLabel);
            GUILayout.Space(mySpace);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Creates the editor GUI for editing, creating, and applying implicit surface shaders.
    /// </summary>
    private void EditImplicitSurfaceGUI()
    {
        GUILayout.Label("Edit Implicit Surfaces", EditorStyles.boldLabel);
        GUILayout.Space(mySpace);

        // Get active game object
        GameObject active = null;
        if (!GetActiveGameObject(ref active)) return;

        // Get shader name
        if (!GetShaderNameGUI(ref shaderNameField)) return;

        // Get implicit surface function definition
        if (!GetImplicitSurfaceFunctionGUI(ref implicitSurfaceFunctionField)) return;

        applyToSelected = GUILayout.Toggle(applyToSelected, "Apply Shader to Selected Material?");
        deletePrevious = GUILayout.Toggle(deletePrevious, "Delete previous shader?");

        GUILayout.Space(mySpace / 2);
        // Generate shader button
        if (GUILayout.Button("Generate Shader"))
        {
            DeletePreviousShader(active);

            // Generate the shader text
            string newShaderText = GenerateShaderText(implicitSurfaceFunctionField);

            // Write new shader
            string newFilePath = AssetDatabase.GenerateUniqueAssetPath("Assets/Implicit Surface Rendering/Implicit Surfaces/" + shaderNameField + ".shader");
            File.WriteAllText(newFilePath, newShaderText);
            AssetDatabase.Refresh();

            ApplyShaderAtPathToSelected(active, newFilePath);
        }
    }

    /// <summary>
    /// Gets and sets the active game object.
    /// </summary>
    /// <param name="active">A reference to the active game object we are getting and setting.</param>
    /// <returns>Whether or not there is a game object selected.</returns>
    private bool GetActiveGameObject(ref GameObject active)
    {
        active = Selection.activeGameObject;

        if (active == null)
        {
            GUILayout.Label("No game object selected.", EditorStyles.whiteLabel);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Gets and sets the shader name field.
    /// </summary>
    /// <param name="shaderName">A reference to the shader name we are getting and setting.</param>
    /// <returns>Whether or not the shader name was not null and not empty).</returns>
    private bool GetShaderNameGUI(ref string shaderName)
    {
        GUILayout.BeginHorizontal();
        GUILayout.Label("Shader Name:");
        shaderName = GUILayout.TextField(shaderName);
        GUILayout.EndHorizontal();

        if (shaderName == null || shaderName.Equals(""))
        {
            GUILayout.Space(mySpace);
            GUILayout.Label("Shader name cannot be empty.", EditorStyles.whiteLabel);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Gets and sets the implicit surface function field.
    /// </summary>
    /// <param name="implicitSurfaceFunctionField">A reference to the implicit surface function field we are getting and setting.</param>
    /// <returns>Whether or not the implicit surface function field not null and not empty.</returns>
    private bool GetImplicitSurfaceFunctionGUI (ref string implicitSurfaceFunctionField)
    {
        GUILayout.Space(mySpace / 2);
        GUILayout.Label("float implicitSurface(float3 p, float _Param1, ..., )");
        GUILayout.Label("{");
        implicitSurfaceFunctionField = GUILayout.TextArea(implicitSurfaceFunctionField, EditorStyles.textArea);
        GUILayout.Label("}");

        if (implicitSurfaceFunctionField == null || implicitSurfaceFunctionField.Equals(""))
        {
            GUILayout.Label("Implicit surface function input cannot be empty.", EditorStyles.whiteLabel);
            return false;
        }

        return true;
    }

    /// <summary>
    /// Deletes the previous managed shader if specified.
    /// </summary>
    /// <param name="active">The active game object with the corresponding shader we are deleting.</param>
    private void DeletePreviousShader(GameObject active)
    {
        // Get the active game object's material and shader
        Material material = active.GetComponent<MeshRenderer>().sharedMaterial;
        Shader shader = material.shader;

        // Only delete previous shader if we managed it (i.e. if it has the managed marker as its first line)
        string shaderPath = AssetDatabase.GetAssetPath(shader);

        // If the shader path is valid and we specify to delete the previous shader
        if (shaderPath != null && deletePrevious && File.Exists(shaderPath))
        {
            string shaderText = File.ReadAllText(shaderPath);
            // Read the first line of the shader
            using (var reader = new StringReader(shaderText))
            {
                string firstLine = reader.ReadLine();
                // If its marked as managed, delete it
                if (firstLine.Equals(managedMarked))
                {
                    AssetDatabase.DeleteAsset(shaderPath);
                }
            }
        }
    }

    /// <summary>
    /// If specified, applies the shader located at the specified path to the specified game object.
    /// </summary>
    /// <param name="gameObject">The game object we are applying the shader to.</param>
    /// <param name="shaderPath">The "Asset" directory-relative file path of the shader.</param>
    private void ApplyShaderAtPathToSelected(GameObject gameObject, string shaderPath)
    {
        if (applyToSelected)
        {
            Shader generated = (Shader)AssetDatabase.LoadMainAssetAtPath(shaderPath);

            gameObject.GetComponent<MeshRenderer>().sharedMaterial.shader = generated;

        }
    }

    /// <summary>
    /// Generates shader text from the implicitSurface function and blueprints.
    /// </summary>
    /// <remarks>This implementation simulates specific preprocessor include statements using string search and replace. It is designed specifically to work with the ISShader.shader, ISLighting.cginc, ISShadows.cginc, ISRendering.cginc blueprints and ISImplicitSurface.cginc files.</remarks>
    private string GenerateShaderText(string implicitSurfaceFunction)
    {
        // StringBuilder to build our shader
        StringBuilder ISImplicitSurfaceSB = new StringBuilder()
            ;

        // Create ISImplicitSurface.cginc
        ISImplicitSurfaceSB.AppendLine("#if !defined(IS_IMPLICIT_SURFACE)");
        ISImplicitSurfaceSB.AppendLine("#define IS_IMPLICIT_SURFACE");
        ISImplicitSurfaceSB.AppendLine("float implicitSurface(float3 p)");
        ISImplicitSurfaceSB.AppendLine("{");
        ISImplicitSurfaceSB.AppendLine(implicitSurfaceFunction);
        ISImplicitSurfaceSB.AppendLine("}");
        ISImplicitSurfaceSB.AppendLine("#endif");
        string ISImplicitSurfaceCginc = ISImplicitSurfaceSB.ToString();

        // Read ISRendering.cginc
        string ISRenderingPath = AssetDatabase.GetAssetPath(ISRenderingBlueprint);
        string ISRenderingText = File.ReadAllText(ISRenderingPath);

        // Create ISLighting.cginc
        string ISLightingPath = AssetDatabase.GetAssetPath(ISLightingBlueprint);
        string ISLightingText = File.ReadAllText(ISLightingPath);

        string replace1 = ISLightingText.Replace("#include \"ISImplicitSurface.cginc\"", ISImplicitSurfaceCginc);
        string replace2 = replace1.Replace("#include \"ISRendering.cginc\"", ISRenderingText);
        string ISLightingCginc = replace2;

        // Create ISShadows.cginc
        string ISShadowsPath = AssetDatabase.GetAssetPath(ISShadowsBlueprint);
        string ISShadowsText = File.ReadAllText(ISShadowsPath);

        string replace3 = ISShadowsText.Replace("#include \"ISImplicitSurface.cginc\"", ISImplicitSurfaceCginc);
        string replace4 = replace3.Replace("#include \"ISRendering.cginc\"", ISRenderingText);
        string ISShadowsCginc = replace4;

        // Create ISShader.shader
        string ISShaderPath = AssetDatabase.GetAssetPath(ISShaderBlueprint);
        string ISShaderText = File.ReadAllText(ISShaderPath);
        string replace5 = ISShaderText.Replace("Shader \"Implicit Surfaces/Library/ISShader\"", "Shader \"Implicit Surfaces/My Surfaces/" + shaderNameField + "\"");
        string replace6 = replace5.Replace("#include \"ISLighting.cginc\"", ISLightingCginc);
        string replace7 = replace6.Replace("#include \"ISShadows.cginc\"", ISShadowsCginc);

        // Append the managedMarked header to the top of the generated shader text
        StringBuilder shaderTextStringBuilder = new StringBuilder();
        shaderTextStringBuilder.AppendLine(managedMarked);
        shaderTextStringBuilder.AppendLine(replace7);

        return shaderTextStringBuilder.ToString();
    }
}
