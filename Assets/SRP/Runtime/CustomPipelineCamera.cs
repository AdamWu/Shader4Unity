using UnityEngine;

[ImageEffectAllowedInSceneView, RequireComponent(typeof(Camera))]
public class CustomPipelineCamera : MonoBehaviour {

	[SerializeField]
	CustomPostProcessingStack postProcessingStack = null;
	
	public CustomPostProcessingStack PostProcessingStack {
		get {
			return postProcessingStack;
		}
	}
}