import asyncio

import edge_tts


async def main() -> None:
    voices = await edge_tts.list_voices()
    print(f"TOTAL={len(voices)}")
    bengali = [v["ShortName"] for v in voices if v["Locale"].startswith("bn")]
    english = [v["ShortName"] for v in voices if v["Locale"].startswith("en-US")]
    print(f"BN={bengali[:12]}")
    print(f"EN={english[:8]}")


asyncio.run(main())
