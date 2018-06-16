require "bundler/setup"
require "tilt"
require "basic_object" if RUBY_VERSION =~ /^1\.8\./
require "require_relative" if RUBY_VERSION =~ /^1\.8\./
require "sass/plugin/rack"
require File.join(File.dirname(__FILE__), *%w{lib supplier_quotations})

mod = SupplierQuotations

mod::Web.configure do
  mod::Config.load File.join(File.dirname(__FILE__), "config.yml")
  mod::Config.connect

  use Rack::ShowExceptions
  use Rack::MethodOverride

  Sass::Plugin.options[:css_location] = "./public/assets/styles"
  Sass::Plugin.options[:template_location] = "./public/assets/styles/scss"
  Sass::Plugin.options[:cache_location] = "./tmp/sass-cache"
  use Sass::Plugin::Rack

  map("/") {run mod::Web}
end

