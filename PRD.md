# Product Requirements Document: OnDeviceAI

**Status:** Draft  
**Product:** OnDeviceAI for iPhone  
**Last updated:** 2026-10-11

## 1. Summary

OnDeviceAI is an iPhone app for running common AI tasks locally and comparing Apple-provided intelligence capabilities with open-weight models. Users choose a task, provide an input, run it with either provider, inspect the output, and compare both results side by side.

The product is intended as a practical evaluation tool. It should make model and task differences visible while keeping the selected inputs and run settings consistent enough for a useful comparison.

## 2. Problem

People evaluating on-device AI options lack a simple way to run the same real-world task through Apple’s available intelligence capabilities and locally run open-weight models. They need to understand output quality, speed, device requirements, and limitations before choosing an approach.

## 3. Goals

- Run text generation through Apple’s Foundation Models framework and supported open-weight models.
- Provide a common workspace for image generation, text-to-speech (TTS), speech-to-text (STT), optical character recognition (OCR), and object identification.
- Let users compare Apple and open-weight results for equivalent tasks and inputs.
- Clearly identify the provider, model, settings, run status, and timing for each result.
- Keep user content and inference on device where the selected capability supports it; disclose when a capability or model requires another execution path.

## 4. Non-goals

- Training or fine-tuning models in the app.
- Claiming that two providers use identical architectures or produce deterministic results.
- Replacing general-purpose image, audio, or file editing apps.
- Shipping a model marketplace or hosting a model download service.
- Treating every Apple capability as a single Foundation Models feature. Each capability may use a different Apple framework or system service.

## 5. Users and primary use cases

### Primary user

A developer, student, or technically curious iPhone user evaluating the usefulness and trade-offs of on-device AI.

### Core use cases

1. Enter a prompt and compare generated text from Apple and an open-weight model.
2. Provide a prompt and compare generated images where both selected providers support image generation.
3. Speak or import audio and compare transcription results.
4. Enter text and compare speech output using each supported provider.
5. Provide an image and compare OCR text and object identification results.
6. Review run duration, provider/model metadata, and any unsupported or failed operation.

## 6. Product scope

### Providers

- **Apple:** Use Foundation Models for supported text generation and the appropriate Apple on-device capabilities/frameworks for image, audio, OCR, and vision tasks.
- **Open-weight:** Run compatible open-weight models through the project’s Core AI integration for the same task categories where a compatible model and runtime are available.

The provider must be selected per task based on actual support. The app must not imply that a model supports a modality that it cannot execute.

### Supported task types

| Task | Input | Result |
| --- | --- | --- |
| Text generation | Prompt and optional context | Generated text |
| Image generation | Prompt and optional reference image, if supported | Generated image |
| TTS | Text and voice/options, if supported | Playable audio |
| STT | Recorded or imported audio | Transcription text |
| OCR | Image or camera capture | Extracted text with available layout information |
| Object identification | Image or camera capture | Detected objects and available confidence/region data |

### Comparison modes

- **Side-by-side:** Run one task against Apple and open-weight providers using the same input and supported settings.
- **Single provider:** Run a task with one provider when the other provider is unavailable or unsupported. Explain why comparison is unavailable.
- **Repeat run:** Allow the user to run again and preserve each result as a distinct run for comparison.

## 7. User experience and flows

### Start a task

1. User opens the app and selects a task type.
2. The app presents the task-specific input area and indicates which providers support that task on the current device.
3. User enters, records, captures, or imports an input.
4. User selects Apple, open-weight, or side-by-side comparison and any shared task options.
5. The app validates availability and begins the run.

### Review and compare

1. Results appear in separate, clearly labeled provider panels.
2. The app shows model/capability name, run state, elapsed time, and task-specific output.
3. Users can play audio, view generated images, copy text, or inspect OCR/object results.
4. If a provider fails or does not support the task, the app keeps the successful result visible and explains the other provider’s state.
5. User can repeat the task, edit the input, or start another task.

## 8. Functional requirements

### FR-1: Task selection

- The app must expose Text Generation, Image Generation, TTS, STT, OCR, and Object Identification as distinct tasks.
- Each task must explain its required input and output.
- Unsupported tasks/providers must be visibly disabled or marked unavailable with a reason.

### FR-2: Apple execution

- Text generation must use Apple’s Foundation Models framework when the device and system support it.
- Other Apple task types must use the appropriate Apple-provided on-device APIs or system capabilities.
- Before execution, the app must handle unavailable, not-ready, or restricted capabilities with an actionable status.
- The app must not silently substitute a different provider.

### FR-3: Open-weight execution

- Users must be able to select a compatible open-weight model for an available task.
- The app must show model name, modality support, local readiness/download state, and relevant resource requirements.
- A task may run only when the selected model and runtime support the task.
- Model loading, unsupported model, memory/resource limitations, and inference failures must have visible states.

### FR-4: Input handling

- Text tasks must support editable text input.
- Audio tasks must support recording and, where permitted by the platform, importing audio.
- Image tasks must support image selection and camera capture where available.
- The same input must be supplied to both providers in a comparison run unless the task requires provider-specific preprocessing; any such difference must be shown.
- Users must be able to edit or clear the input before a run.

### FR-5: Result presentation

- Results must be labeled with provider and model/capability.
- Text output must be readable and selectable/copyable.
- Generated images must be viewable at useful size and saveable through a user-initiated action.
- TTS output must have playback controls.
- STT and OCR outputs must be readable and copyable.
- Object identification output must show detected labels and confidence/regions when returned by the provider.
- Loading, success, partial success, empty output, cancellation, and failure states must be distinct.

### FR-6: Comparison

- The app must show both providers’ results together for side-by-side runs.
- The app must record elapsed time and the provider/model used for each run.
- The comparison view must identify input and settings used so users can determine whether a comparison is equivalent.
- If a provider does not support a task or fails, the other result must remain available.
- The app must avoid presenting a single opaque quality score as objective truth. Users should be able to inspect outputs and measured characteristics directly.

### FR-7: History and privacy

- Users must be able to review results from the current session and start a fresh run.
- Persisted history, if added, must be opt-in or clearly disclosed and provide a way to clear it.
- The app must state where input data is processed and whether it is stored or sent off device.
- Permissions for microphone, camera, and photo access must be requested only when the relevant feature is used.

## 9. Non-functional requirements

- **On-device operation:** Prefer local inference and local processing. State clearly when any operation uses network access.
- **Reliability:** A failure in one provider must not terminate the other provider’s run or remove a completed result.
- **Responsiveness:** Show progress promptly for model loading and long-running inference; allow cancellation where the underlying API permits it.
- **Resource awareness:** Present model storage requirements and handle memory pressure or unsupported device capability without crashing.
- **Accessibility:** Support Dynamic Type, VoiceOver labels, sufficient contrast, and controls that do not rely on color alone.
- **Compatibility:** Gate features by OS version, device capability, model availability, and runtime support.
- **Transparency:** Distinguish measured facts (such as elapsed time) from subjective quality assessments.

## 10. Success measures

- Users can complete one comparison for every modality supported by both providers on their device.
- Every result clearly identifies its provider, model/capability, and elapsed time.
- Unsupported, unavailable, and failed states explain what happened and preserve any successful result.
- Users can complete the main task flow without encountering a dead-end model or modality selection.
- Qualitative evaluation confirms that the side-by-side result is understandable and that task inputs/settings are clear.

## 11. MVP and delivery phases

### MVP

- Task selection and provider availability display.
- Text generation through Foundation Models and at least one compatible open-weight model.
- A side-by-side comparison view with prompt, outputs, provider/model labels, run state, and elapsed time.
- Error handling for unsupported devices/models and failed runs.

### Follow-on capabilities

- Add image generation, TTS, STT, OCR, and object identification one task at a time as Apple and open-weight implementations are validated.
- Add model import/download management and storage reporting.
- Add session history, export, and richer task-specific result inspection.

The MVP is successful only when the supported provider paths are real executions. Placeholder outputs or UI-only demonstrations do not meet the execution requirements.

## 12. Acceptance criteria

1. A user can enter a text prompt and run it through Apple Foundation Models and an available open-weight model.
2. In comparison mode, both providers receive the same prompt and shared settings, and both outputs are displayed with provider/model labels.
3. Each run shows elapsed time and a clear status; one provider’s error does not hide the other provider’s result.
4. For each additional modality, the app lists provider support and only enables execution when a compatible implementation is available.
5. For image/audio inputs, permission denial and unsupported input formats produce clear recovery guidance.
6. The app discloses whether processing is local and never sends user input to another service without a visible disclosure and user action.
7. Users can clear the active input and begin a new run without restarting the app.

## 13. Risks and dependencies

- Apple capability and Foundation Models availability depend on OS version, device, locale, and system readiness.
- Open-weight model availability depends on runtime integration, model licensing, modality support, device memory, and storage.
- Equivalent comparisons may not be possible when providers expose different parameters, preprocessing, or output formats.
- Image generation, TTS, STT, OCR, and object identification may use different models or system APIs; provider labels must describe the actual executor.
- Model files and generated media can consume substantial storage and memory.

## 14. Open decisions

- Confirm the exact product/runtime meant by **“Core AI”** and its supported model formats and modalities. The current UI says “GGUF/CoreAI,” while the project currently imports Apple’s `FoundationModels` framework for text-model integration.
- Confirm minimum supported iPhone models and OS version for each capability.
- Decide which modalities are in the first release after text-generation comparison.
- Decide whether open-weight models are bundled, downloaded, or imported by the user.
- Define supported licenses and model provenance requirements for shipped or downloadable models.
- Decide whether inputs/results are retained after the current app session and whether export is required.
- Define the evaluation protocol for quality comparisons, including repeat counts and task-specific measures beyond latency.
