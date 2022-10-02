If *puma* is able to run in domain **httpd_t** by setting *ruby* SELinux type
to **httpd_exec_t**, i.e.:

```shell
sudo semanage fcontext -a -t httpd_exec_t ~puma/.asdf/installs/ruby/3.1.2/bin/ruby
sudo restorecon -F ~puma/.asdf/installs/ruby/3.1.2/bin/ruby
```

then it will need read access to user content and network connectivity
to the database, i.e.:

```shell
sudo setsebool -P httpd_read_user_content 1
sudo setsebool -P httpd_can_network_connect_db 1
```

If *puma* runs in the domain **initrc_t**, then in order for *nginx*
to connect to **initrc_t:unix_stream_socket*, run:


```shell
sudo grep nginx /var/log/audit/audit.log | audit2allow -m nginx >nginx.te
checkmodule -o nginx.mod -m nginx.te
semodule_package -o nginx.pp -m nginx.mod
sudo semodule -i nginx.pp
sudo systemctl restart nginx
```


```shell
sbin/puma --no-config --environment production --threads 5:5 --workers 2 \
    --bind unix:///run/puma/oauth/sockets/puma.sock --state /run/puma/oauth/puma.state \
    --control-url unix:///run/puma/oauth/sockets/pumactl.sock --control-token oauth \
    --pidfile /run/puma/oauth/pids/server.pid
```

Audit.log issue resolved by instaling module *nginx.pp*:

> type=AVC msg=audit(1655204634.928:569): avc:  denied  { connectto } for  pid=2027 comm="nginx" path="/run/puma/oauth/sockets/puma.sock" scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:system_r:initrc_t:s0 tclass=unix_stream_socket permissive=1
