"""Offline package smoke checks: no model downloads or microphone access."""

import tempfile
import wave
from pathlib import Path
from unittest.mock import patch

import av
import ctranslate2
import faster_whisper
import pyannote.audio
import torch
import torchaudio
from faster_whisper.audio import decode_audio
from torchcodec.decoders import AudioDecoder

from tapeback import const
from tapeback.diarizer import Diarizer, diarization_available
from tapeback.settings import Settings

assert diarization_available()
assert const.PYANNOTE_MODEL == "pyannote/speaker-diarization-community-1"
assert ctranslate2.get_supported_compute_types("cpu")

# Exercise both audio decoders and the torch/torchaudio ABI without models.
with tempfile.TemporaryDirectory() as directory:
    audio = Path(directory) / "silence.wav"
    with wave.open(str(audio), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16000)
        wav.writeframes(bytes(32000))
    assert decode_audio(str(audio)).shape == (16000,)
    assert AudioDecoder(str(audio)).get_all_samples().data.shape == (1, 16000)
    assert torchaudio.functional.resample(torch.zeros(1, 16000), 16000, 8000).shape == (1, 8000)

    # A CUDA Whisper setting must not send the CPU-only diarizer to CUDA.
    with patch("pyannote.audio.Pipeline.from_pretrained") as load, patch(
        "torch.cuda.is_available", return_value=False
    ):
        Diarizer(Settings(vault_path=Path(directory), hf_token="offline-test", device="cuda"))
        load.return_value.to.assert_not_called()

print("Offline imports, audio decoding, and CPU diarization fallback passed.")
