# Sinatra::CanvasAuth

CanvasAuth is a Sinatra extension that implements the [OAuth2 flow](https://canvas.instructure.com/doc/api/file.oauth.html) used for authenticating a user via [Canvas LMS](https://github.com/instructure/canvas-lms).

This gem handles redirection of unauthenticated/unauthorized users, as well as the routing & API calls necessary for logging in/obtaining an access token, logging out/deleting an access token.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sinatra-canvas_auth'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sinatra-canvas_auth


## Usage
If you are developing a ["classic-style"](http://www.sinatrarb.com/intro.html#Modular%20vs.%20Classic%20Style) Sinatra app, require the files at the top of your app, enable sessions, and set the required configuration options.

``` ruby
require sinatra
require sinatra/canvas_auth

# These settings are required
configure do
    enable :sessions
    set :canvas_url, 'https://ucdenver.instructure.com'
    set :client_id, 10230000000000045
    set :client_secret, '659df93f24affc25948ee437f8ac825edfa903d95e3a5ace0bb5ac4fb61686c6'
end

get '/' do
    'Hello World'
end
```

For "modular-style" apps, you must also explicitly register the extension
``` ruby
require sinatra/base
require sinatra/canvas_auth

class App < Sinatra::Base

    # These settings are required
    configure do
        enable :sessions
        set :canvas_url, 'https://ucdenver.instructure.com'
        set :client_id, 10230000000000045
        set :client_secret, '659df93f24affc25948ee437f8ac825edfa903d95e3a5ace0bb5ac4fb61686c6'
    end

    register Sinatra::CanvasAuth

    get '/' do
       'Hello World'
    end
end
```

## Configuration
CanvasAuth pulls settings from your Sinatra app's configuration, which can be set with [the built-in DSL](http://www.sinatrarb.com/configuration.html).

For simplicity, examples in this documentation hard-code configuration within the application, though it is often wise to use alternate methods when configuring sensitive data (e.g. API keys), especially when working with open source. Here are just a few options that can help you with this:
* [Sinatra::ConfigFile](http://www.sinatrarb.com/contrib/config_file.html)
* [Dotenv](https://github.com/bkeepers/dotenv)
* [Figaro](https://github.com/laserlemon/figaro)

CanvasAuth requires a baseline configuration to function, as Canvas API settings will differ between instances. Below is a full list of the available configuraiton options.

#### Required Settings

* **canvas_url** (String)

  The full URL of the Canvas instance used for authentication.

  ```ruby
  set :canvas_url, 'https://ucdenver.instructure.com'
  ```

* **client_id** (String)

  The client id (AKA "ID") for the developer key associated with your app. Developer keys can be requested [here](http://goo.gl/yu4lT), or created directly by Canvas admins by clicking "Developer Keys" on the sidebar under your account's admin panel.
  ```ruby
  set :client_id, 10230000000000045
  ```

* **client_secret** (String)

  The 64 character client secret (AKA "Key") for the developer key associated with your app.
  ```ruby
  set :client_secret, '659df93f24affc25948ee437f8ac825edfa903d95e3a5ace0bb5ac4fb61686c6'
  ```
&nbsp;


#### Optional Settings

* **auth_paths** (Array)  
  Default: [/.*/]  
  To only require authentication for certain routes, they may be explicitly specified here with either strings or regular expression. By default, all app routes will require authentication.
  ```ruby
  set :auth_paths, ['/admin', /^\/courses\/(\d)+$]
  ```

  Alternative syntax:
  ```ruby
  authenticate '/admin', /^\/courses\/(\d)+$
  ```

* **oauth_callback** (Proc)

  Once the OAuth authentication request has been made, this proc is called with the API response from Canvas. This may be used to define a custom response handling action, such as saving the user's token in a database.
  ```ruby
  set :oauth_callback, Proc.new { |oauth_response|
    uid = oauth_response['user']['id']
    token = oauth_response['access_token']
    db_connection.execute("UPDATE users SET access_token = ? where uid = ?", token, uid)
  }
  ```

* **authorized** (Proc)

  This proc may be defined to check the authorization priveleges of a user once they have logged in. It should return truthy for authorized users, falsy otherwise. Since this is called without parameters, it generally makes use of session variables and/or settings which were set during the oauth_callback proc or elsewhere in the app.

  ```ruby
  set :authorized, Proc.new {
    session[:allowed_roles].includes?(session[:user_roles])
  }
  ```

* **unauthorized_redirect** (String)  
  Default: "/unauthorized"  
  If the above "authorized" setting is provided and returns falsy when called, the user will be redirected to this path.
  ```ruby
  set :unauthorized_redirect, '/not_allowed'
  ```

* **logout_redirect** (String)  
  Default: "/logged-out"  
  After a user is logged out, they will be redirected to this path.
  ```ruby
  set :logout_redirect, '/goodbye'
  ```
## Miscellaneous Notes
* CanvasAuth automatically assigns `session['user_id']` and `session['access_token']` to the values returned by the OAuth response, so there is no need to do this manually in your oauth_callback proc.

* The following routes are defined by CanvasAuth for use in the OAuth flow and should not be overridden by your application:
  * GET  /canvas-auth-login
  * GET  /canvas-auth-logout
  * POST /canvas-auth-token

* The following routes are also defined by CanvasAuth, but only as placeholders that may (and should) be overridden by your application. They do not include any functionality and serve only as landing pages to prevent 404ing on the default redirects.
  * GET /unauthorized
  * GET /logged-out

* All routes defined by CanvasAuth are permanently exempt from the requiring authentication, to avoid redirect loops.
## Contributing

Feeback, bug reports, and pull requests are welcome and appreciated.

1. Fork it ( https://github.com/CUOnline/sinatra-canvas_auth/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
