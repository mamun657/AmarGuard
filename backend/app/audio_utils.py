import io
import logging
import wave
from dataclasses import dataclass

from .errors import AudioFormatError, PayloadTooLargeError

logger = logging.getLogger("caresignal.audio")

TARGET_SAMPLE_RATE = 16000
SUPPORTED_SAMPLE_RATES = {16000, 24000}
MAX_CLIP_SECONDS = 120


@dataclass
class NormalizedAudio:
    wav_bytes: bytes
    sample_rate: int
    channels: int
    duration_ms: int
    converted: bool


def ensure_wav(
    audio_bytes: bytes,
    *,
    max_bytes: int,
    max_seconds: int = MAX_CLIP_SECONDS,
) -> NormalizedAudio:
    if not audio_bytes:
        raise AudioFormatError("The recording is empty.")
    if len(audio_bytes) > max_bytes:
        raise PayloadTooLargeError("The recording exceeds the allowed upload size.")

    try:
        with wave.open(io.BytesIO(audio_bytes), "rb") as source:
            channels = source.getnchannels()
            sample_width = source.getsampwidth()
            sample_rate = source.getframerate()
            frames = source.readframes(source.getnframes())
    except (wave.Error, EOFError) as error:
        raise AudioFormatError("The recording is not a readable WAV file.") from error

    if channels == 0 or sample_width == 0 or sample_rate == 0:
        raise AudioFormatError("The recording is not readable audio.")

    duration_ms = int(len(frames) / (sample_rate * channels * sample_width) * 1000)
    if duration_ms > max_seconds * 1000:
        raise AudioFormatError(
            f"Recordings must be shorter than {max_seconds} seconds."
        )

    needs_conversion = (
        channels != 1
        or sample_width != 2
        or sample_rate not in SUPPORTED_SAMPLE_RATES
    )
    if not needs_conversion:
        return NormalizedAudio(
            wav_bytes=audio_bytes,
            sample_rate=sample_rate,
            channels=channels,
            duration_ms=duration_ms,
            converted=False,
        )

    pcm = _to_mono_16bit(frames, channels, sample_width)
    resampled = _resample(pcm, sample_rate, TARGET_SAMPLE_RATE)
    output = io.BytesIO()
    with wave.open(output, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(TARGET_SAMPLE_RATE)
        writer.writeframes(resampled)
    return NormalizedAudio(
        wav_bytes=output.getvalue(),
        sample_rate=TARGET_SAMPLE_RATE,
        channels=1,
        duration_ms=duration_ms,
        converted=True,
    )


def _to_mono_16bit(frames: bytes, channels: int, sample_width: int) -> bytes:
    import array

    if sample_width == 2:
        samples = array.array("h")
        samples.frombytes(frames[: len(frames) - (len(frames) % 2)])
        if channels > 1:
            usable = len(samples) - (len(samples) % channels)
            mono = array.array(
                "h",
                [
                    sum(samples[index : index + channels]) // channels
                    for index in range(0, usable, channels)
                ],
            )
        else:
            mono = samples
        return mono.tobytes()

    if sample_width == 1:
        raw = frames[: len(frames) - (len(frames) % 1)]
        return array.array(
            "h", [(byte - 128) * 256 for byte in raw]
        ).tobytes()

    if sample_width == 4:
        samples = array.array("i")
        samples.frombytes(frames[: len(frames) - (len(frames) % 4)])
        usable = len(samples) - (len(samples) % channels)
        mono = array.array(
            "i",
            [
                sum(samples[index : index + channels]) // channels
                for index in range(0, usable, channels)
            ],
        )
        return array.array("h", _clip_16(mono)).tobytes()

    raise AudioFormatError("Unsupported PCM sample width in the recording.")


def _clip_16(values: "array.array[int]") -> list[int]:
    return [max(-32768, min(32767, value // 65536)) for value in values]


def _resample(pcm: bytes, source_rate: int, target_rate: int) -> bytes:
    import array

    samples = array.array("h")
    samples.frombytes(pcm)
    if source_rate == target_rate:
        return pcm
    if not samples:
        return pcm
    ratio = target_rate / source_rate
    target_length = max(1, int(len(samples) * ratio))
    output = array.array("h", bytes(target_length * 2))
    last_index = len(samples) - 1
    for index in range(target_length):
        position = index / ratio
        left = int(position)
        right = min(left + 1, last_index)
        fraction = position - left
        value = samples[left] + (samples[right] - samples[left]) * fraction
        output[index] = max(-32768, min(32767, int(value)))
    return output.tobytes()
