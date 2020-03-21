{
  # Postpone loading the GPU driver until X starts.
  boot.kernelParams = [
    "i915.modeset=0"
    "nouveau.modeset=0"
    "nvidia.modeset=0"
    "radeon.modeset=0"
    "nomodeset"
  ];
}
