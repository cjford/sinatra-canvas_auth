require 'test_helper'

class IntegrationTests < Minitest::Test
  def test_get_login_path
    state = 'a1b2c3'
    script_name = '/testscript'
    SecureRandom.stubs(:urlsafe_base64).returns(state)
    expected_redirect = "https://canvasurl.com/login/oauth2/auth?" \
                        "client_id=123&" \
                        "response_type=code&" \
                        "state=#{state}&" \
                        "redirect_uri=http%3A%2F%2Fexample.org%2Fcanvas-auth-token"

    get app.login_path

    assert_equal 302, last_response.status
    assert_equal expected_redirect, last_response.headers['Location']

    assert_equal session['oauth_state'], state
  end

  def test_get_login_with_script_name
    state = 'a1b2c3'
    script_name = '/testscript'
    redirect = '/redirected-from/123'
    SecureRandom.stubs(:urlsafe_base64).returns(state)

    expected_redirect = "https://canvasurl.com/login/oauth2/auth?" \
                        "client_id=123&" \
                        "response_type=code&" \
                        "state=#{state}&" \
                        "redirect_uri=http%3A%2F%2Fexample.org%2Ftestscript%2Fcanvas-auth-token"

    env = {
      'SCRIPT_NAME' => script_name,
      'rack.session' => {'oauth_redirect' => redirect}
    }

    get app.login_path, {}, env
    assert_equal 302, last_response.status
    assert_equal expected_redirect, last_response.headers['Location']

    assert_equal session['oauth_redirect'], redirect
    assert_equal session['oauth_state'], state
  end

  def test_get_login_path_default_redirect
    state = 'a1b2c3'
    script_name = '/testscript'
    SecureRandom.stubs(:urlsafe_base64).returns(state)

    expected_redirect = "https://canvasurl.com/login/oauth2/auth?" \
                        "client_id=123&" \
                        "response_type=code&" \
                        "state=#{state}&" \
                        "redirect_uri=http%3A%2F%2Fexample.org%2Ftestscript%2Fcanvas-auth-token"

    get app.login_path, {}, {'SCRIPT_NAME' => script_name}

    assert_equal 302, last_response.status
    assert_equal expected_redirect, last_response.headers['Location']

    assert_equal session['oauth_redirect'], script_name
    assert_equal session['oauth_state'], state
  end


  def test_get_login_path_with_optional_params
    state = 'a1b2c3'
    SecureRandom.stubs(:urlsafe_base64).returns(state)

    expected_redirect = "https://canvasurl.com/login/oauth2/auth?" \
                        "client_id=123&" \
                        "response_type=code&" \
                        "state=#{state}&" \
                        "redirect_uri=http%3A%2F%2Fexample.org%2Fcanvas-auth-token&" \
                        "scope=auth%2Fuserinfo&purpose=testing&" \
                        "force_login=true&" \
                        "unique_id=a1b2c3"

    request_params = {
      :scope => 'auth/userinfo',
      :purpose => 'testing',
      :force_login => true,
      :unique_id => 'a1b2c3'
    }

    get app.login_path, request_params

    assert_equal 302, last_response.status
    assert_equal expected_redirect, last_response.headers['Location']
  end


  def test_get_logout_path
    access_token = 456
    RestClient::Request.expects(:execute).with({
      :method => :delete,
      :url    => "https://canvasurl.com/login/oauth2/token",
      :headers => {
        :authorization => "Bearer #{access_token}"
      }
    }).returns('')

    get app.logout_path, {}, {'rack.session' => {'access_token' => access_token }}
    assert_equal 302, last_response.status
    assert !session.has_key?('user_id') && !session.has_key?('access_token')

    follow_redirect!
    assert_equal 200, last_response.status
  end

  def test_get_logout_path_with_optional_params
    access_token = 456
    RestClient::Request.expects(:execute).with({
      :method => :delete,
      :url    => "https://canvasurl.com/login/oauth2/token&expire_sessions=1",
      :headers => {
        :authorization => "Bearer #{access_token}"
      }
    }).returns('')

    get app.logout_path, {:expire_sessions => true},
        {'rack.session' => {'access_token' => access_token }}

    assert_equal 302, last_response.status
    assert !session.has_key?('user_id') && !session.has_key?('access_token')

    follow_redirect!
    assert_equal 200, last_response.status
  end

  def test_get_token_path
    state = 'a1b2c3'
    user_id = 123
    redirect = '/redirected_from/123'
    access_token = 456
    api_response = {'access_token' => access_token, 'user' => { 'id' => user_id }}.to_json
    RestClient.stubs(:post).returns(api_response)
    app.any_instance.expects(:oauth_callback)

    env = {
      'rack.session' => {
        'oauth_state' => state,
        'oauth_redirect' => redirect }}

    get app.token_path, {}, env
    assert_equal 302, last_response.status
    assert_equal user_id, session['user_id']
    assert_equal access_token, session['access_token']

    follow_redirect!
    assert_equal redirect, last_request.path
  end

  def test_get_token_path_invalid_state
    state = 'a1b2c3'
    redirect = '/redirected_from/123'
    message = 'state error'

    Sinatra::CanvasAuth.expects(:verify_oauth_state)
                       .raises(Sinatra::CanvasAuth::StateError, message)
    RestClient.expects(:post).never
    app.any_instance.expects(:oauth_callback).never

    env = {
      'rack.session' => {
        'oauth_state' => state,
        'oauth_redirect' => redirect }}

    get app.token_path, {}, env
    assert_equal 302, last_response.status
    assert_nil session['user_id']
    assert_nil session['access_token']

    follow_redirect!
    assert_equal app.failure_redirect, last_request.path
    assert_match /#{message}/, last_response.body
  end

  def test_get_token_path_error
    RestClient.expects(:post).raises(RestClient::Exception)

    get app.token_path
    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal app.failure_redirect, last_request.path
    assert_match /Authentication Failed/, last_response.body
  end

  def test_get_login_failure
    error = 'oopsy'
    get "#{app.failure_redirect}?error=#{error}"
    assert_equal 200, last_response.status
    assert_match error, last_response.body
  end

  def test_unauthenticated_request
    RestClient.stubs(:post).returns("{}")

    get '/', {}, {'rack.session' => {}}
    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal 302, last_response.status
    assert_equal app.settings.login_path, last_request.path

    follow_redirect!
    assert_equal '/login/oauth2/auth', last_request.path
  end

  def test_unauthorized_request
    app.any_instance.expects(:authorized).returns(false)

    get '/', {}, {'rack.session' => {'user_id' => 123}}
    assert_equal 302, last_response.status

    follow_redirect!
    assert_equal app.unauthorized_redirect, last_request.path
  end

  def test_authorized_request
    app.any_instance.expects(:authorized).returns(true)
    get '/', {}, {'rack.session' => {'user_id' => 123}}
    assert last_response.ok?
  end
end
