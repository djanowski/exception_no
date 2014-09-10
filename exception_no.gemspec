require File.expand_path("lib/exception_no", File.dirname(__FILE__))

Gem::Specification.new do |s|
  s.name              = "exception_no"
  s.version           = ExceptionNo::VERSION
  s.summary           = "Truly basic exception notification."
  s.authors           = ["Educabilia", "Damian Janowski"]
  s.email             = ["opensource@educabilia.com", "djanowski@dimaion.com"]
  s.homepage          = "https://github.com/djanowski/exception_no"

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test}/*`.split("\n")

  s.license = "Unlicense"

  s.add_development_dependency "cutest"
  s.add_development_dependency "mini-smtp-server"
  s.add_development_dependency "rack"
end
