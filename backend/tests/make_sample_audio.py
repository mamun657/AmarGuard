import subprocess
import sys
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent

SAMPLES = [
    ("sample_bn", "bn-BD-NabanitaNeural", "আমি পথ হারিয়ে ফেলেছি, আমার ছেলেকে জানাও।"),
    ("sample_en", "en-US-AriaNeural", "I am lost. Please help me contact my family."),
    ("sample_mixed", "bn-BD-NabanitaNeural", "Ami lost hoye gesi, please amar family ke inform koro."),
]


def _run(command: list[str]) -> None:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"{command[0]} failed: {result.stderr.strip()[:300]}")


def main() -> int:
    for name, voice, text in SAMPLES:
        mp3 = OUTPUT_DIR / f"{name}.mp3"
        wav = OUTPUT_DIR / f"{name}.wav"
        try:
            import edge_tts
            import asyncio

            asyncio.run(edge_tts.Communicate(text, voice).save(str(mp3)))
            _run(
                [
                    "ffmpeg",
                    "-y",
                    "-loglevel",
                    "error",
                    "-i",
                    str(mp3),
                    "-ac",
                    "1",
                    "-ar",
                    "16000",
                    "-acodec",
                    "pcm_s16le",
                    str(wav),
                ]
            )
            print(f"WROTE {wav.name} bytes={wav.stat().st_size}")
        except Exception as error:
            print(f"FAILED {name}: {type(error).__name__}: {error}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
