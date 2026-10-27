# Leo Rover Simulation in Docker (ROS 2 Humble + Gazebo Fortress)

SEDS Pakistan, IST Chapter: task **SEDS-TASK-ROV-SRILANKA-001**
Candidate: Hassan Ali, Pod 3A (Autonomous Navigation, Computer Vision & Systems Integration)

One command starts a **headless** (no window) Gazebo simulation of the Leo Rover
and publishes its ROS 2 topics, including `/odom`. It behaves the same on
Windows, Linux and macOS because everything runs inside the container.

## Requirements
- Docker Desktop (Windows / macOS) or Docker Engine with the Compose plugin (Linux)
- About 6 GB free disk space and internet access for the first build
- Nothing else: no ROS, Gazebo or Python install on the host

## Run
```bash
docker compose up --build
```
The first build takes 10-20 minutes because it downloads ROS and Gazebo. Later starts take seconds.

Stop: `Ctrl+C`, then `docker compose down`.

## Verify
In a second terminal, while the simulation is running:
```bash
docker compose ps                                                   # STATUS shows "healthy" once /odom arrives
docker compose exec leo-sim /entrypoint.sh ros2 topic list
docker compose exec leo-sim /entrypoint.sh ros2 topic echo --once /odom
docker compose exec leo-sim /entrypoint.sh ros2 topic hz /odom
```

Drive the rover (optional; shows the simulation responds to commands):
```bash
docker compose exec leo-sim /entrypoint.sh ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.3}}"
```

## Files
| File | Purpose |
|---|---|
| `Dockerfile` | Starts from the official `ros:humble-ros-base-jammy` image, downloads the Leo simulator source (tag `1.1.2`), installs its dependencies with `rosdep` and builds it with `colcon` |
| `compose.yml` | Runs `leo_gz.launch.py` headless (`-s -r --headless-rendering`) and defines the `/odom` health check |
| `scripts/entrypoint.sh` | Loads ROS and the built workspace, then runs the command |

## Options
| Variable | Default | Effect |
|---|---|---|
| `LEO_WORLD` | `leo_empty` | Gazebo world: `leo_empty`, `marsyard2020`, `marsyard2021`, `marsyard2022` |
| `ROS_DOMAIN_ID` | `0` | ROS 2 network ID; give each simulation sharing a network its own number |

Example: `LEO_WORLD=marsyard2022 docker compose up` (PowerShell: `$env:LEO_WORLD="marsyard2022"; docker compose up`).

## Notes
- Gazebo flags: `-s` = server only (headless), `-r` = start running immediately
  (a paused simulator publishes no `/odom`), `--headless-rendering` = the camera sensor renders without a display.
- Rendering runs on the CPU (Mesa), so no GPU is needed. Small laptops will run the simulation slower than real time.
- Source of the simulator: [LeoRover/leo_simulator-ros2](https://github.com/LeoRover/leo_simulator-ros2) (MIT),
  the same package as `03_Track2_Planetary_Rover_Arsenal/leorover-leo_simulator-ros2` in the Crucible Resource Package.
