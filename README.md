# Frigate bridge for V380 / V380 Pro Wi-Fi cameras (AWT3610E, AliOS Things)

A bridge that turns cheap V380 / V380 Pro Wi-Fi IP cameras, which have **no RTSP, no ONVIF and no shell**, into local **RTSP video and audio streams** that [Frigate](https://frigate.video) (and Home Assistant, VLC, ffmpeg or any RTSP client) can use without the cloud app. The bridge is a third-party decoder run once per camera; this repo holds the notes, test results and launcher script.

**Status of the Frigate part: the camera-to-RTSP half is tested; Frigate pulling the streams is not.** Details below.

**Search terms:** V380, V380 Pro, V380 RTSP, V380 Frigate, AWT3610E, `Hw_AWT3610E_XHR_E_V1.0_WF`, AliOS Things camera, cheap Chinese Wi-Fi camera, white-label OEM IP camera, no ONVIF, no RTSP, port 8800, port 9800, local stream without cloud, PTZ dome Wi-Fi camera.

**Which cameras?** Tested only on two `AWT3610E` units. Many unrelated shop brands sell cameras that use the V380 Pro app (for example Kerui, Hikwifi, Verto and LS Vision were named by other owners), but **other brands and models were not tested here** and may use different firmware, ports or login rules.

**Status: draft, written from one person's tests on two cameras. Nothing here is guaranteed to work on yours.** Every claim says whether it was tested.

## The cameras

- Sold under many shop brands, using the V380 Pro app. Board or model code on the app screens: `AWT3610E`. Two units tested: one fixed camera and one outdoor pan-tilt dome.
- Firmware string seen on both: `Hw_AWT3610E_XHR_E_V1.0_WF_20231114`.
- The firmware is **AliOS Things (an RTOS), not Linux.** The usual tricks for V380 cameras (an SD-card web server, enabling telnet or RTSP through a config file or patch) need a Linux shell and **do not apply**. Reading a config file from the SD card was tried and changed nothing.
- On the LAN the cameras answer on TCP **8800** (and 9800 on some units). Nothing else useful was open.
- Each camera has its **own device username** (V380 app, camera settings, password page) and device ID. The default username `admin` is rejected with a camera-side error.

## What worked (tested)

The [AspirantDrago/V380Decoder](https://github.com/AspirantDrago/V380Decoder) fork of V380Decoder (a .NET tool that speaks the V380 protocol, decodes the stream and serves it as RTSP and as a JPEG snapshot) gave a working stream from both cameras:

| Test | Result |
|---|---|
| Login on the LAN, each camera with its own username | worked |
| Snapshot (`/snapshot`), 1280x720 JPEG | worked, real picture |
| RTSP video, 1280x720 H.264, about 20 fps, 0.4 to 1 Mbps | worked |
| RTSP audio, A-law (G.711) 8 kHz mono | arrives; level responds to sound; whether it sounds right was not confirmed by listening |
| One camera, RTSP held open 4 minutes and 2 minutes | no drop |
| Both cameras at once (two decoder instances on different ports), 2 minutes, with audio | no drop |

**Not tested:** runs of hours or days, behaviour after a Wi-Fi or camera drop over time, CPU load, Frigate itself pulling the streams, running the decoder in Docker, auto-start after reboot, motion events from the camera (the decoder's own docs say it does not expose them; Frigate does its own motion detection from the video).

## What did not work, and was not explained

- The **original** V380Decoder logged in, then received nothing after the start-stream command, on both cameras.
- The fork's **first** run on one camera received the stream headers and was then closed by the camera on every attempt, with no frames. Later runs on the same camera, with the same command, worked. **Cause unknown.** Ideas that were not tested: the camera refuses new sessions for a while after earlier ones, or its state differed after earlier runs. If you see `Camera closed the media connection`, stop everything that talks to the camera (including the phone app), wait, and try again cold.
- Another owner of the same firmware family reported that the SD-card tricks and several V380 web tools did not work for them either.

## How to run it (what was done)

1. Install the .NET SDK, clone the fork, build it. Review the source first: it is third-party code and it logs the stream key in debug mode.
2. Find each camera's username and device ID in the V380 app. Keep the phone app **closed** while testing.
3. Copy `scripts/Run-Camera.example.ps1`, fill in your values for each camera, and give each camera **its own ports** (for example RTSP 8554 and snapshot 8080 for the first, 8555 and 8081 for the second). The script asks for the password with a masked prompt.
4. Check from the same machine:

```powershell
# snapshot: expect HTTP 200 and a JPEG
Invoke-WebRequest http://127.0.0.1:8080/snapshot -OutFile snap.jpg

# a 15-second capture over RTSP, with a hard time limit
ffmpeg -rtsp_transport tcp -timeout 10000000 -i rtsp://127.0.0.1:8554/live -an -c copy -t 15 test.mp4
```

Always put a time limit on ffmpeg here: an unlimited run against a silent stream hung for minutes.

5. For audio, use `-map 0 -c copy` into `.mkv`, or convert to AAC for `.mp4`. Give **every** output its own `-t`, or one output keeps running.

## Safety notes

- Without `--secure`, the decoder's RTSP and snapshot ports are open on your LAN with **no login** while it runs. With `--secure` it **prints the password**, so do not use it in logs you share.
- The decoder sends a UDP broadcast for discovery and, in cloud mode, posts the device ID to the vendor's server. LAN mode talks to the camera directly.
- The decoder depends on a version of `SixLabors.ImageSharp` that NuGet flags with known vulnerabilities. The risk is low while it decodes only your own cameras' frames on your LAN, but think before exposing it.
- Never commit passwords, device IDs, stream keys or Wi-Fi details.

## Frigate (planned, not tested)

Each camera becomes one RTSP input: `rtsp://<decoder-host>:8554/live` for the first and `rtsp://<decoder-host>:8555/live` for the second, one stream per camera used for both detection and recording. The decoder has to run all the time and restart on its own; that is not set up.

A starting point for the Frigate config. **Not tested, and the option names change between Frigate versions, so check it against your version's documentation:**

```yaml
cameras:
  camera1:
    ffmpeg:
      inputs:
        - path: rtsp://<decoder-host>:8554/live
          input_args: preset-rtsp-generic
          roles: [detect, record]
    detect:
      width: 1280
      height: 720
      fps: 5
  camera2:
    ffmpeg:
      inputs:
        - path: rtsp://<decoder-host>:8555/live
          input_args: preset-rtsp-generic
          roles: [detect, record]
    detect:
      width: 1280
      height: 720
      fps: 5
```

The audio is A-law (G.711); recording it may need an audio output option or re-encoding to AAC. Motion detection is done by Frigate from the video, so the camera does not need to send motion events. If you get Frigate working with this, please open an issue or pull request with your working config.

## Licence

MIT, see `LICENSE`. This covers the notes and the example script only. The third-party decoder is not part of this repo and keeps its own terms.
