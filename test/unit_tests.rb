require 'test_helper'

class UnitTests < Minitest::Test
  def test_merge_defaults_with_no_settings
    defaults = Sinatra::CanvasAuth::DEFAULT_SETTINGS.dup
    mock_app = mock()

    defaults.each do |setting, value|
      mock_app.expects(:set).with(setting, value)
    end

    Sinatra::CanvasAuth.merge_defaults(mock_app)
  end

  def test_merge_defaults_with_existing_settings
    defaults = Sinatra::CanvasAuth::DEFAULT_SETTINGS.dup
    mock_app = mock()
    mock_app.stubs(:auth_paths).returns([])
    assert defaults.delete(:auth_paths)
    mock_app.stubs(:login_path).returns('/login')
    assert defaults.delete(:login_path)

    defaults.each do |setting, value|
      mock_app.expects(:set).with(setting, value)
    end

    Sinatra::CanvasAuth.merge_defaults(mock_app)
  end

  def test_auth_path_defaults
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/courses')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/anything/123')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '!@#$%^&*()')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-login')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-logout')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-token')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/unauthorized')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/logged-out')
  end

  def test_auth_path_defaults_with_script_name
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-login', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-logout', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/canvas-auth-token', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/unauthorized', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/logged-out', '/myapp')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/canvas-auth-login', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/canvas-auth-logout', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/canvas-auth-token', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/unauthorized', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/logged-out', '/myapp')
  end

  def test_auth_path_with_regex
    app.set :auth_paths, [/^\/courses\/(\d)+$/]

    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/courses/1')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/courses/999')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, 'courses/1')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/courses/1/2')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/foo/1')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/courses999')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/c/courses/999')

    app.set :auth_paths, [/.*abc$/]

    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/fffabc')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/123/fffabc')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/courses/abc')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/abc123')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test/abc/1')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/foo/1')
  end

  def test_auth_path_exclude_self_paths
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test2')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test3')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test4')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test5')

    app.set :login_path, '/test'
    app.set :logout_path, '/test2'
    app.set :token_path, '/test3'
    app.set :logout_redirect, '/test4'
    app.set :unauthorized_redirect, '/test5'

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test2')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test3')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test4')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test5')
  end

  def test_auth_path_exclude_self_paths_with_script_name
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test2', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test3', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test4', '/myapp')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test5', '/myapp')

    app.set :login_path, '/test'
    app.set :logout_path, '/test2'
    app.set :token_path, '/test3'
    app.set :logout_redirect, '/test4'
    app.set :unauthorized_redirect, '/test5'

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test2', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test3', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test4', '/myapp')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/myapp/test5', '/myapp')
  end

  def test_auth_paths_exclude_public
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/abc')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/abc-a')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/abc-1')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test-a')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test-1')

    app.set :public_paths, ['/abc', /^\/.+-\d/]

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/abc')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/abc-a')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/abc-1')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test-a')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test-1')
  end

  def test_auth_paths_set_manually
    app.set :auth_paths, ['/test1', '/test2']

    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test1')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test2')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test3')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/foo')
  end

  def test_auth_paths_set_with_authenticate
    app.authenticate '/test4', '/test5', '/test6'

    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test4')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test5')
    assert Sinatra::CanvasAuth.auth_path?(app.settings, '/test6')

    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test2')
    assert !Sinatra::CanvasAuth.auth_path?(app.settings, '/test3')
  end

  def test_login_url
    test_app = app.new
    state = '/teststate'
    login_path ='/testlogin'
    script_name = '/testscript'

    mock_request = OpenStruct.new(:env => {'SCRIPT_NAME' => script_name})
    mock_settings = OpenStruct.new(:login_path => login_path)
    Sinatra::Base.any_instance.stubs(:request).returns(mock_request)
    Sinatra::Base.any_instance.stubs(:settings).returns(mock_settings)

    assert_equal "#{script_name}#{login_path}#{state}", test_app.helpers.login_url(state)
  end

  def test_login_url_no_state
    test_app = app.new
    login_path ='/testlogin'
    script_name = '/testscript'

    mock_request = OpenStruct.new(:env => {'SCRIPT_NAME' => script_name})
    mock_settings = OpenStruct.new(:login_path => login_path)
    Sinatra::Base.any_instance.stubs(:request).returns(mock_request)
    Sinatra::Base.any_instance.stubs(:settings).returns(mock_settings)

    assert_equal "#{script_name}#{login_path}", test_app.helpers.login_url
  end

  def test_login_url_no_request_context
    test_app = app.new
    refute test_app.helpers.login_url
  end

  def test_render_view
    test_app = app.new
    header = 'header'
    message = 'message'
    view_path = 'viewpath'

    expected_options = {
      :views => view_path,
      :locals => {
        :header => header,
        :message => message
      }
    }
    File.stubs(:expand_path).returns(view_path)
    Sinatra::Base.any_instance.expects(:render).with(:erb, :canvas_auth, expected_options)

    test_app.helpers.render_view(header, message)
  end

  def test_verify_oauth_state
    state = 'a1b2c3'
    params = {'state' => state}
    session = {'oauth_state' => state}
    assert_nil Sinatra::CanvasAuth.verify_oauth_state(params, session)
  end

  def test_verify_oauth_state_mismatch
    state = 'a1b2c3'
    params = {'state' => state}
    session = {'oauth_state' => state + 'xxx'}
    assert_raises Sinatra::CanvasAuth::StateError do
      Sinatra::CanvasAuth.verify_oauth_state(params, session)
    end
  end

end
