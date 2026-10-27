# ---------------------------------------------------------------------------
# Leo Rover - ROS 2 Humble + Gazebo Fortress, headless simulation image
# Task: SEDS-TASK-ROV-SRILANKA-001
# ---------------------------------------------------------------------------
# Official ROS image: multi-arch (amd64 + arm64), so the same file works on
# Windows/Linux (Intel/AMD) and Apple-silicon Macs through Docker Desktop.
FROM ros:humble-ros-base-jammy

# Version of the Leo simulator to build. 1.1.2 is the last Humble/Fortress
# release of github.com/LeoRover/leo_simulator-ros2 (branch "humble"); it is
# the package that provides leo_gz_bringup/launch/leo_gz.launch.py.
ARG LEO_SIM_REPO=https://github.com/LeoRover/leo_simulator-ros2.git
ARG LEO_SIM_REF=1.1.2

ENV DEBIAN_FRONTEND=noninteractive \
    ROS_WS=/ws \
    GZ_VERSION=fortress \
    # No GPU and no display inside the container: render in software (Mesa).
    LIBGL_ALWAYS_SOFTWARE=1 \
    QT_QPA_PLATFORM=offscreen

# 1) Build tools + Mesa software-rendering libraries so Gazebo's camera
#    sensor can render without a monitor (EGL headless rendering).
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        python3-colcon-common-extensions \
        libegl1 \
        libegl-mesa0 \
        libgl1-mesa-dri \
        libglx-mesa0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR ${ROS_WS}

# 2) Fetch the simulator source at a fixed version so every team builds
#    exactly the same code.
RUN git clone --depth 1 --branch ${LEO_SIM_REF} ${LEO_SIM_REPO} src/leo_simulator-ros2 \
    && rm -rf src/leo_simulator-ros2/.git

# 3) Install every dependency the packages declare in package.xml
#    (Gazebo Fortress, ros_gz_sim, ros_gz_bridge, leo_description, xacro ...).
#    No "-r" flag: if a dependency can't be installed the build must fail.
RUN apt-get update \
    && rosdep update --rosdistro ${ROS_DISTRO} \
    && rosdep install --from-paths src --ignore-src -y --rosdistro ${ROS_DISTRO} \
    && rm -rf /var/lib/apt/lists/*

# 4) Build the workspace (tests off: we only need the runtime packages).
RUN . /opt/ros/${ROS_DISTRO}/setup.sh \
    && colcon build --merge-install \
         --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    && rm -rf build log

# 5) Entrypoint: loads ROS + our workspace, then runs whatever command it is
#    given. sed strips Windows CRLF line endings just in case.
COPY scripts/entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "launch", "leo_gz_bringup", "leo_gz.launch.py", \
     "sim_world:=-s -r --headless-rendering /ws/install/share/leo_gz_worlds/worlds/leo_empty.sdf"]
