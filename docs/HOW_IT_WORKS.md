# How this works

A short tour for teammates who have not used Docker, ROS 2 or Gazebo before.

## The pieces

| Piece | What it is | Role here |
|---|---|---|
| **Docker image** | A frozen Linux system with everything pre-installed | Ubuntu 22.04 + ROS 2 Humble + Gazebo Fortress + the Leo simulator |
| **Docker container** | A running copy of the image | Where the simulation actually runs |
| **Dockerfile** | The recipe for building the image | Read top to bottom, each `RUN` is one step |
| **compose.yml** | Says *how* to run the container | Command, health check, environment variables |
| **ROS 2** | Middleware: programs ("nodes") exchange messages on named "topics" | `/odom`, `/cmd_vel`, `/imu/data_raw`, `/camera/image_raw` ... |
| **Gazebo (Fortress)** | Physics simulator | Simulates the rover, wheels, IMU, camera |
| **ros_gz_bridge** | Translator | Copies Gazebo messages onto ROS 2 topics and back |

## What happens on `docker compose up --build`

1. **Build** (`Dockerfile`, first time only, cached later)
   1. Start from the official `ros:humble-ros-base-jammy` image.
   2. Install `git`, `colcon` (the ROS build tool) and the Mesa libraries for CPU rendering.
   3. `git clone` the Leo simulator at tag `1.1.2`, so every team builds the same code.
   4. `rosdep install` reads each `package.xml` and apt-installs what it lists (Gazebo, bridges, the rover model `leo_description`, ...).
   5. `colcon build` compiles the workspace into `/ws/install`.
2. **Run** (`compose.yml`)
   - `entrypoint.sh` loads ROS (`source setup.bash`), then runs
     `ros2 launch leo_gz_bringup leo_gz.launch.py sim_world:="-s -r --headless-rendering <world>.sdf"`.
3. **Inside the launch file** (`leo_gz.launch.py` → `spawn_robot.launch.py`)
   - starts the Gazebo **server** with the given world (`-s` means no GUI),
   - turns the robot's URDF (xacro) into a description and publishes it (`robot_state_publisher`),
   - spawns the rover in the world (`ros_gz_sim create`),
   - starts bridges: `/clock`, `/cmd_vel`, `/odom`, `/tf`, `/imu/data_raw`, `/camera/*`, `/joint_states`.
4. **Health check**: every 15 s Docker runs `ros2 topic echo --once /odom` inside the container.
   When a message arrives, `docker compose ps` shows `healthy`. That is the check the task asks for.

## Message flow

```
              Gazebo server (headless)
  diff-drive plugin ──odometry──► ros_gz_bridge ──► /odom  (nav_msgs/Odometry)
         ▲                                     ◄── /cmd_vel (geometry_msgs/Twist)
         └──────────── wheel commands ◄────────┘
```

## Why each flag matters
- `-s`: server only. A GUI window cannot open in a container without a display.
- `-r`: run immediately. Gazebo starts paused otherwise, and a paused sim publishes no `/odom`.
- `--headless-rendering`: the rover's camera is a rendering sensor. This flag renders it off-screen with EGL, so there is no crash for lack of a display.
- `LIBGL_ALWAYS_SOFTWARE=1`: use the CPU renderer (llvmpipe), so no GPU is needed on any laptop.
- `shm_size: 1gb`: ROS 2's default DDS transport uses shared memory, and Docker's default is only 64 MB.

## Connecting your own node
Teammates' nodes (odometry, ArUco, rock detection) can run in the same container:
```bash
docker compose exec leo-sim /entrypoint.sh bash     # a shell with ROS loaded
```
They can also run in another container on the same compose network with the same `ROS_DOMAIN_ID`.
