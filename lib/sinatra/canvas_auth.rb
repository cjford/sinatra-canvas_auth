require 'sinatra'
require 'rest-client'

module Sinatra
  module CanvasAuth

    DEFAULT_SETTINGS = {
      :auth_paths            => [/.*/],
      :canvas_url            => nil,
      :client_id             => nil,
      :client_secret         => nil,
      :failure_redirect      => '/login-failure',
      :login_path            => '/canvas-auth-login',
      :token_path            => '/canvas-auth-token',
      :logout_path           => '/canvas-auth-logout',
      :logout_redirect       => '/logged-out',
      :public_paths          => [],
      :unauthorized_redirect => '/unauthorized'
    }.freeze

    # Just a prettier syntax for setting auth_paths
    def authenticate(*paths)
      set :auth_paths, paths
    end

    def self.registered(app)
      self.merge_defaults(app)

      app.helpers do
        def login_url(state = nil)
          return false if request.nil?
          path_elements = [request.env['SCRIPT_NAME'], settings.login_path]
          path_elements << state if state
          File.join(path_elements)
        end

        def render_view(header='', message='')
          render(:erb, :canvas_auth, {
            :views => File.expand_path(File.dirname(__FILE__)),
            :locals => {
              :header => header,
              :message => message
            }
          })
        end
      end

      app.get app.login_path do
        params['state'] ||= request.env['SCRIPT_NAME']
        redirect_uri = "#{request.scheme}://#{request.host_with_port}" \
                       "#{request.env['SCRIPT_NAME']}#{settings.token_path}"

        redirect_params = "client_id=#{settings.client_id}&" \
                          "response_type=code&" \
                          "state=#{CGI.escape(params['state'])}&" \
                          "redirect_uri=#{CGI.escape(redirect_uri)}"

        ['scope', 'purpose', 'force_login', 'unique_id'].each do |optional_param|
          if params[optional_param]
            redirect_params += "&#{optional_param}=#{CGI.escape(params[optional_param])}"
          end
        end

        redirect "#{settings.canvas_url}/login/oauth2/auth?#{redirect_params}"
      end

      app.get app.token_path do
        payload = {
          :code          => params['code'],
          :client_id     => settings.client_id,
          :client_secret => settings.client_secret
        }

        begin
          response = RestClient.post("#{settings.canvas_url}/login/oauth2/token", payload)
        rescue RestClient::Exception => e
          failure_url = File.join(request.env['SCRIPT_NAME'], settings.failure_redirect)
          failure_url += "?error=#{params[:error]}" unless params[:error].nil?
          redirect failure_url
        end

        response = JSON.parse(response)
        session['user_id'] = response['user']['id']
        session['access_token'] = response['access_token']
        oauth_callback(response) if self.respond_to?(:oauth_callback)

        redirect params['state']
      end

      app.get app.logout_path do
        if session['access_token']
          delete_url = "#{settings.canvas_url}/login/oauth2/token"
          delete_url += "&expire_sessions=1" if params['expire_sessions']

          RestClient::Request.execute({
            :method  => :delete,
            :url     => delete_url,
            :headers => {
              :authorization => "Bearer #{session['access_token']}"
            }
          })
        end
        session.clear
        redirect to(settings.logout_redirect)
      end

      app.get app.logout_redirect do
        render_view('Logged out', 'You have been successfully logged out')
      end

      app.get app.unauthorized_redirect do
        render_view('Authentication Failed',
                    'Your canvas account is unauthorized to view this resource')
      end

      app.get app.failure_redirect do
        message = "Login could not be completed."
        message += " (#{params[:error]})" if params[:error] && !params[:error].empty?
        render_view("Authentication Failed", message)
      end

      # Redirect unauthenticated/unauthorized users before hitting app routes
      app.before do
        current_path = "#{request.env['SCRIPT_NAME']}#{request.env['PATH_INFO']}"
        if CanvasAuth.auth_path?(self.settings, current_path, request.env['SCRIPT_NAME'])
          if session['user_id'].nil?
            redirect "#{request.env['SCRIPT_NAME']}#{settings.login_path}?state=#{current_path}"
          elsif self.respond_to?(:authorized) && !authorized
            redirect "#{request.env['SCRIPT_NAME']}#{settings.unauthorized_redirect}"
          end
        end
      end
    end

    # Should the current path ask for authentication or is it public?
    def self.auth_path?(app, current_path, script_name = '')
      exempt_paths = [ app.login_path, app.token_path, app.logout_path,
                       app.logout_redirect, app.unauthorized_redirect,
                       app.failure_redirect ]

      app.auth_paths.select{ |p| current_path.match(p) }.any? &&
      !app.public_paths.select{ |p| current_path.match(p) }.any? &&
      !exempt_paths.map{|p| File.join(script_name, p)}.include?(current_path)
    end

    def self.merge_defaults(app)
      DEFAULT_SETTINGS.each do |key, value|
        if !app.respond_to?(key)
          app.set key, value
        end
      end
    end
  end

  register CanvasAuth
end
