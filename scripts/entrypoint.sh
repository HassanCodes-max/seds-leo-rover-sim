#!/bin/bash
set -e
# Load ROS 2 Humble and the workspace built in the Dockerfile.
source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "${ROS_WS}/install/setup.bash"
exec "$@"
