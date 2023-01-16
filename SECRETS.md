# Revo OpenProject Server

This document explains how to securely configure and run the Revo OpenProject Server.

## Installing from Source

Clone the repository and install dependencies:

```shell
git clone https://github.com/revolution-robotics.com/revo-openproject.git
cd revo-openproject
bundle install
yarn install
asdf reshim nodejs
```

Initialize proudction database

```shell
psql -U postgres -c "create database openproject_production with owner = 'revo';"
psql -U revo openproject_production <db/structure.sql
bin/rails db:seed
bin/rails assets:precompile
```

Create an intermediate database-credentials template,
*config/database-credentials.template*, to transfer credentials from a
sops-encrypted to a Rails-encrypted file:


```shell
cat >config/database-credentials.template <<'EOF'
development:
  database:
    name: $dev_db_name
    username: $dev_db_user
    password: $dev_db_pass
    host: $dev_db_host
    port: $dev_db_port
test:
  database:
    name: $test_db_name
    username: $test_db_user
    password: $test_db_pass
    host: $test_db_host
    port: $test_db_port
production:
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

Create a Rails credentials file, *config/credentials.yml.enc*, by
applying the database secrets to the credentials template:sops exec-env config/database-secrets.enc.yml \
    'EDITOR=ed bin/rails credentials:edit <<EOF
r !envsubst <config/database-credentials.template
wq
EOF
'



```shell
sops exec-env config/database-secrets.sops.yml \
    'EDITOR=ed bin/rails credentials:edit <<EOF
r !envsubst <config/database-credentials.template
wq
EOF
'
```

where the utility `envsubst` is available as part of the *gettext*
package.

## Deploying a Production Server

In the following deployment command, let the app runs as system user
**puma** on remote server **tau**, and let the remote admin username
be **revo**. If account **puma** does not already exist on the remote
system, see, e.g., the script `setup-system-user` from repository
*fedora-server-setup*.

Add an .ssh/config entry for Host **tau** with sign-in **revo**. Then,
in the app repository on the local system, run:

```shell
./contrib/deploy-to-remote tau revo puma
```
