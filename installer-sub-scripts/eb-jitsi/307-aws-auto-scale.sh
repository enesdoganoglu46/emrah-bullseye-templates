# -----------------------------------------------------------------------------
# AWS-AUTO-SCALE.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jitsi-host"
cd $MACHINES/$MACH

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$INSTALL_AWS_AUTO_SCALE" != true ] && exit

echo
echo "---------------------- AWS AUTO SCALE ---------------------"

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# awscli
apt-get $APT_PROXY_OPTION -y --no-install-recommends install awscli

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
