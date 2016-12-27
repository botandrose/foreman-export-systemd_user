# Foreman export scripts for user-level systemd on Ubuntu 16.04

```ruby
# Gemfile
gem "foreman-export-systemd_user"
```

then

```
bundle exec foreman export systemd-user --app <app-name>
systemctl --user enable <app-name>.target
systemctl --user start <app-name>.target
```
