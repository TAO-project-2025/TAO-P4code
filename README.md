
# TAO (Table-centric Asynchronous flow Offloading)

## Environment Description
The container environment is created by Tencent based on Ruijie programmable switches. Modifications were made to adapt the project to the laboratory switch environment.
1. In the cmake folder, the line `-DP4PPFLAGS="-Xp4c=--disable-parse-depth-limit"` in the p4.cmake file was commented out, as sde 9.7.0 does not support this command.

### Laboratory Environment

Tofino switch environment configuration:
- Physical machine OS: 3.16.39-OpenNetworkLinux
- Container OS: "Debian GNU/Linux 9 (stretch)"

Command: `./p4studio configure --bsp-path ../../bf-platforms-ingrasys-bsp-9.7.0.tgz`

The following will be updated:
- `/home/buildsde/bf-sde-9.7.1/pkgsrc/bf-platforms`
- `/home/buildsde/bf-sde-9.7.1/install/lib` (libpltfm.so)

BSP updates depend on the host operating system.
