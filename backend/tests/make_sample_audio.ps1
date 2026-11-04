Add-Type -AssemblyName System.Speech

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

$voices = $synth.GetInstalledVoices()
foreach ($voice in $voices) {
    Write-Output ("VOICE: " + $voice.VoiceInfo.Name + " | " + $voice.VoiceInfo.Culture)
}

$synth.SetOutputToWaveFile("$PSScriptRoot\sample_en.wav")
$synth.Speak("I am lost. Please help me contact my family.")

$synth.Dispose()

Get-Item "$PSScriptRoot\sample_en.wav" | Select-Object Name, Length
