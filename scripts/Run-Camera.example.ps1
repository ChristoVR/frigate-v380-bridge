# Example launcher for the V380Decoder fork. Copy it, give the copy a name per camera
# (for example Run-Doorway.ps1), fill in the four values below, and keep the copy OUT of git
# if it holds a real device ID. Asks only for the password (masked). Stop with Ctrl+C.
#
# Do not add --secure: it prints the password.
# While this runs, the RTSP and snapshot ports are open on the LAN with no login.
#
# Not tested by this repo's author on other firmware.

$CameraName = "Camera1"          # label for the prompt only
$DeviceId   = "<device-id>"      # from the V380 app device list
$Username   = "<username>"       # the camera's own username, from the app (not "admin")
$CameraIp   = "<camera-ip>"      # the camera's LAN address (give it a DHCP reservation)
$RtspPort   = 8554               # use a different pair for each camera, e.g. 8555 and 8081
$HttpPort   = 8080

Set-Location $PSScriptRoot       # the folder that holds V380Decoder.csproj
$pw = Read-Host "$CameraName password" -MaskInput
dotnet run --project .\V380Decoder.csproj -c Release -- --id $DeviceId --username $Username --password $pw --ip $CameraIp --rtsp-port $RtspPort --http-port $HttpPort --debug
