# Upstart user-level export scripts for systemd on Ubuntu 16.04

```ruby
gem "foreman-export-systemd_user"
```

then

```bash
bundle exec foreman export systemd-user --app <app-name>
systemctl --user enable <app-name>.target
systemctl --user start <app-name>.target
```

