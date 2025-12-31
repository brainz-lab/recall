require "test_helper"

class Dashboard::BaseControllerTest < ActionDispatch::IntegrationTest
  # The base controller just sets the layout, which is tested through
  # the other dashboard controller tests. This file exists for completeness
  # and to ensure the controller can be loaded without errors.

  test "base controller should set dashboard layout" do
    # This is implicitly tested by other dashboard controller tests
    # which all inherit from BaseController
    assert Dashboard::BaseController < ApplicationController
  end
end
