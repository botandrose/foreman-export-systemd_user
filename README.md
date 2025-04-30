# Foreman export scripts for user-level systemd on Ubuntu 16.04+

```ruby
# Gemfile
gem "foreman-export-systemd_user"
```

then

```
bundle exec foreman export systemd-user --app <app-name>
```

This will also run the following:
```
loginctl enable-linger
systemctl --user enable <app-name>.target
```

To restart, run:
```
systemctl --user restart <app-name>.target
```

