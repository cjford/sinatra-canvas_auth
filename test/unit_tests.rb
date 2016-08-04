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

end
