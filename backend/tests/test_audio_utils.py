import io
import wave

import pytest

from app.audio_utils import ensure_wav
from app.errors import AudioFormatError, PayloadTooLargeError


def _wav_bytes(
    *,
    channels: int = 1,
    sample_width: int = 2,
    sample_rate: int = 16000,
    frames: int = 16000,
) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(sample_width)
        writer.setframerate(sample_rate)
        writer.writeframes(b"\x00\x01" * (frames * channels))
    return buffer.getvalue()


def test_accepts_supported_mono_16bit_16khz():
    audio = _wav_bytes()
    result = ensure_wav(audio, max_bytes=10 * 1024 * 1024)
    assert result.converted is False
    assert result.sample_rate == 16000
    assert result.channels == 1
    assert result.wav_bytes == audio


def test_accepts_supported_mono_16bit_24khz():
    audio = _wav_bytes(sample_rate=24000)
    result = ensure_wav(audio, max_bytes=10 * 1024 * 1024)
    assert result.converted is False
    assert result.sample_rate == 24000


def test_converts_unsupported_rate_to_mono_16khz():
    audio = _wav_bytes(sample_rate=44100)
    result = ensure_wav(audio, max_bytes=10 * 1024 * 1024)
    assert result.converted is True
    assert result.sample_rate == 16000
    assert result.channels == 1
    with wave.open(io.BytesIO(result.wav_bytes), "rb") as reader:
        assert reader.getnchannels() == 1
        assert reader.getsampwidth() == 2
        assert reader.getframerate() == 16000


def test_converts_stereo_to_mono():
    audio = _wav_bytes(channels=2)
    result = ensure_wav(audio, max_bytes=10 * 1024 * 1024)
    assert result.converted is True
    assert result.channels == 1
    with wave.open(io.BytesIO(result.wav_bytes), "rb") as reader:
        assert reader.getnchannels() == 1


def test_rejects_empty_payload():
    with pytest.raises(AudioFormatError):
        ensure_wav(b"", max_bytes=10 * 1024 * 1024)


def test_rejects_oversized_payload():
    with pytest.raises(PayloadTooLargeError):
        ensure_wav(_wav_bytes(), max_bytes=16)


def test_rejects_recording_longer_than_limit():
    audio = _wav_bytes(sample_rate=16000, frames=48000 * 3)
    with pytest.raises(AudioFormatError):
        ensure_wav(audio, max_bytes=10 * 1024 * 1024, max_seconds=2)
