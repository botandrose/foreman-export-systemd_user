$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "foreman-export-systemd_user"
  s.version     = "0.1.2"
  s.authors     = ["Micah Geisel"]
  s.email       = ["micah@botandrose.com"]
  s.homepage    = "http://github.com/botandrose/foreman-export-systemd_user"
  s.summary     = "Foreman export scripts for user-level systemd"
  s.description = "Foreman export scripts for user-level systemd"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "foreman", ">= 0.90.0"

  s.add_development_dependency "rspec"
end
