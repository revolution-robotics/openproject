# OpenProject Server

This document explains how to securely configure and run the OpenProject Server.

## Manual Deployment

Clone the repository and install dependencies:

```shell
git clone https://github.com/revolution-robotics.com/openproject.git
cd openproject
bundle install
yarn install
asdf reshim nodejs
```

Initialize proudction database

```shell
psql -U postgres -c "create database openproject with owner = 'openproject';"
psql -U openproject openproject <db/structure.sql
bin/rails db:seed
bin/rails assets:precompile
```

Create an intermediate database-credentials template,
*config/database-credentials.template*, to transfer credentials from a
sops-encrypted to a Rails-encrypted file:


```shell
cat >config/database-credentials.template <<'EOF'
database:
  name: $prod_db_name
  username: $prod_db_user
  password: $prod_db_pass
  host: $prod_db_host
  port: $prod_db_port
EOF
```

Initialize a secrets file, *database-secrets.sops.yml*, with template
names and fill in the keyed values of the secrets using the sops
secrets editor:

```shell
EDITOR=ed sops config/database-secrets.sops.yml <<'EOF'
,d
r  !sed -rn -e 's/.*\$(.*)$/\1: /p' config/database-credentials.template
/dev_db_name/s;$;openproject_development;
/test_db_name/s;$;openproject_test;
/prod_db_name/s;$;openproject_production;
g/db_user/s;$;openproject_dbuser;
g/db_pass/s;$;openproject_dbpass;
g/db_host/s;$;localhost;
g/db_port/s;$;5432;
.
wq
EOF
```

where values *openproject_development*, *openproject_test*, ..., *openproject_dbpass*,
*localhost*,  etc. are replaced with credentials that the PostgreSQL
database is configured for.

Create an encrypted Rails credentials file, *config/credentials/production.yml.enc*, by
applying the database secrets to the credentials template:

```shell
sops exec-env config/database-secrets.sops.yml \
    'EDITOR=ed bin/rails credentials:edit --environment production <<EOF
r !envsubst <config/database-credentials.template
wq
EOF
'
```

where the utility `envsubst` is available as part of the *gettext*
package.

## Automated Deployment

In the following deployment command, the app is run as system user
**puma** on remote server **tau**, and the admin username on **tau**
is **revo**. If account **puma** does not already exist on the remote
system, see, e.g., the script `setup-system-user` from repository
*remote-server-setup*.

Add an .ssh/config entry for Host **tau** with login name **revo**. Then,
in the app repository on the local system, run:

```shell
./contrib/deploy-to-remote --admin revo --server tau \
    --app-owner puma --app-name openproject
```
