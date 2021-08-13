# -----------------------------------------------------------------------------
# KRATOS-DB.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000-source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-postgres"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[[ "$DONT_RUN_KRATOS_DB" = true ]] && exit

echo
echo "------------------------ KRATOS DB ------------------------"

# -----------------------------------------------------------------------------
# CONTAINER
# -----------------------------------------------------------------------------
# start the container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# wait for postgresql
lxc-attach -n eb-postgres -- zsh <<EOS
set -e
for try in \$(seq 1 9); do
    systemctl is-active postgresql.service && break || sleep 1
done
EOS

# -----------------------------------------------------------------------------
# BACKUP
# -----------------------------------------------------------------------------
[[ -f $ROOTFS//etc/postgresql/13/main/pg_hba.conf ]] && \
    cp $ROOTFS/etc/postgresql/13/main/pg_hba.conf $OLD_FILES/

# -----------------------------------------------------------------------------
# DROP DATABASE & ROLE
# -----------------------------------------------------------------------------
# drop the old database if RECREATE_KRATOS_DB_IF_EXISTS is set
if [[ "$RECREATE_KRATOS_DB_IF_EXISTS" = true ]]; then
    lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    dropdb -f --if-exists kratos
EOP
EOS

    lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    dropuser --if-exists kratos
EOP
EOS
fi

# -----------------------------------------------------------------------------
# EXISTENCE CHECK
# -----------------------------------------------------------------------------
IS_DB_EXIST=$(lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    psql -At <<< '\l kratos'
EOP
EOS
)

IS_ROLE_EXIST=$(lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    psql -At <<< '\dg kratos'
EOP
EOS
)

# -----------------------------------------------------------------------------
# CREATE ROLE & DATABASE
# -----------------------------------------------------------------------------
[[ -z "$IS_ROLE_EXIST" ]] && lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    createuser -l kratos
EOP
EOS

[[ -z "$IS_DB_EXIST" ]] && lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres <<EOP
    createdb -T template0 -O kratos -E UTF-8 -l en_US.UTF-8 kratos
EOP
EOS

# -----------------------------------------------------------------------------
# UPDATE PASSWD
# -----------------------------------------------------------------------------
DB_PASSWD=$(openssl rand -hex 20)
echo DB_PASSWD="$DB_PASSWD" >> $INSTALLER/000-source

lxc-attach -n eb-postgres -- zsh <<EOS
set -e
su -l postgres -s /usr/bin/psql <<PSQL
    ALTER ROLE kratos WITH PASSWORD '$DB_PASSWD';
PSQL
EOS

# -----------------------------------------------------------------------------
# ALLOWED HOSTS
# -----------------------------------------------------------------------------
lxc-attach -n eb-postgres -- zsh <<EOS
set -e
sed -i '/kratos/d' /etc/postgresql/13/main/pg_hba.conf
EOS

cat etc/postgresql/13/main/pg_hba.conf.kratos \
    >>$ROOTFS/etc/postgresql/13/main/pg_hba.conf

lxc-attach -n eb-postgres -- systemctl restart postgresql.service
