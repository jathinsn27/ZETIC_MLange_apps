import torch
import torch.hub
import numpy as np
import os

# Define paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
EXPORT_DIR = os.path.join(SCRIPT_DIR, "../model_export")
INPUT_DIR = os.path.join(SCRIPT_DIR, "../model_inputs")

os.makedirs(EXPORT_DIR, exist_ok=True)
os.makedirs(INPUT_DIR, exist_ok=True)

# Define Wrapper to handle OrderedDict output
class ModelWrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, x):
        output = self.model(x)
        return output['out']

# Load Model
print("Loading model...")
try:
    # Using specific tag for reproducibility
    base_model = torch.hub.load('pytorch/vision:v0.10.0', 'deeplabv3_resnet101', pretrained=True)
    base_model.eval()
    model = ModelWrapper(base_model)
    model.eval()
except Exception as e:
    print(f"Error loading model: {e}")
    exit(1)

# Prepare Input
# DeeplabV3 uses (N, 3, H, W). Using 520x520 as standard.
input_shape = (1, 3, 520, 520)
dummy_input = torch.randn(input_shape)

# Save Input
np.save(os.path.join(INPUT_DIR, "input.npy"), dummy_input.detach().numpy())
print(f"Saved input to {INPUT_DIR}")

# 1. Export to TorchScript
print("Exporting to TorchScript...")
try:
    traced_model = torch.jit.trace(model, dummy_input)
    torch.jit.save(traced_model, os.path.join(EXPORT_DIR, "model.pt"))
    print("TorchScript export successful.")
except Exception as e:
    print(f"TorchScript export failed: {e}")

# 2. Export to ExportedProgram
print("Exporting to ExportedProgram...")
try:
    exported_program = torch.export.export(model, (dummy_input,))
    torch.export.save(exported_program, os.path.join(EXPORT_DIR, "model.pt2"))
    print("ExportedProgram export successful.")
except Exception as e:
    print(f"ExportedProgram export failed: {e}")

# 3. Export to ONNX
print("Exporting to ONNX...")
try:
    torch.onnx.export(
        model,
        dummy_input,
        os.path.join(EXPORT_DIR, "model.onnx"),
        opset_version=11,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes=None  # Static shape as requested
    )
    print("ONNX export successful.")
except Exception as e:
    print(f"ONNX export failed: {e}")

print("Export complete.")
