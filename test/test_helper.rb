require 'sinatra'
require 'sinatra/canvas_auth'

require 'rack/test'
require 'minitest/autorun'
require 'mocha/mini_test'
require 'ostruct'

class Minitest::Test
  include Rack::Test::Methods

  def reload_sinatra
    # Need to reload entire Sinatra module for classic-style apps
    # Settings tied to singleton persist across tests
    if Object.const_defined?("Sinatra")
      Object.send(:remove_const, "Sinatra")
    end
    $".delete_if {|s| s.include?('sinatra') }

    require 'sinatra'
    require 'sinatra/canvas_auth'
  end

  def setup
    if ENV['app_type'] == 'classic'
      reload_sinatra
      Sinatra::Application.enable :sessions
      Sinatra::Application.set :client_id, '123'
      Sinatra::Application.set :client_secret, 'secret'
      Sinatra::Application.set :session_secret, 'secret'
      Sinatra::Application.set :canvas_url, 'https://canvasurl.com'
      Sinatra::Application.get '/' do  'Hello World' end
    else
      # Don't need to reload for modular apps, just define a new app object
      @app = Sinatra.new do
        enable :sessions
        set :client_id, '123'
        set :client_secret, 'secret'
        set :canvas_url, 'https://canvasurl.com'

        register Sinatra::CanvasAuth
        get '/' do 'Hello World' end
      end
    end
  end

  def app
    ENV['app_type'] == 'classic' ? Sinatra::Application : @app
  end

  def session
    last_request.env['rack.session']
  end
end
