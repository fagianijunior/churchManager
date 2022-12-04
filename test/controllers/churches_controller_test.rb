require "test_helper"

class ChurchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @church = churches(:one)
  end

  test "should get index" do
    get churches_url
    assert_response :success
  end

  test "should get new" do
    get new_church_url
    assert_response :success
  end

  test "should create church" do
    assert_difference("Church.count") do
      post churches_url, params: { church: { fundation_date: @church.fundation_date, name: @church.name } }
    end

    assert_redirected_to church_url(Church.last)
  end

  test "should show church" do
    get church_url(@church)
    assert_response :success
  end

  test "should get edit" do
    get edit_church_url(@church)
    assert_response :success
  end

  test "should update church" do
    patch church_url(@church), params: { church: { fundation_date: @church.fundation_date, name: @church.name } }
    assert_redirected_to church_url(@church)
  end

  test "should destroy church" do
    assert_difference("Church.count", -1) do
      delete church_url(@church)
    end

    assert_redirected_to churches_url
  end
end
