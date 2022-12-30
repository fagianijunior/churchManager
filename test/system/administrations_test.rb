require "application_system_test_case"

class AdministrationsTest < ApplicationSystemTestCase
  setup do
    @administration = administrations(:one)
  end

  test "visiting the index" do
    visit administrations_url
    assert_selector "h1", text: "Administrations"
  end

  test "should create administration" do
    visit administrations_url
    click_on "New administration"

    fill_in "End date", with: @administration.end_date
    fill_in "Occupation", with: @administration.occupation_id
    fill_in "Start date", with: @administration.start_date
    fill_in "User", with: @administration.user_id
    click_on "Create Administration"

    assert_text "Administration was successfully created"
    click_on "Back"
  end

  test "should update Administration" do
    visit administration_url(@administration)
    click_on "Edit this administration", match: :first

    fill_in "End date", with: @administration.end_date
    fill_in "Occupation", with: @administration.occupation_id
    fill_in "Start date", with: @administration.start_date
    fill_in "User", with: @administration.user_id
    click_on "Update Administration"

    assert_text "Administration was successfully updated"
    click_on "Back"
  end

  test "should destroy Administration" do
    visit administration_url(@administration)
    click_on "Destroy this administration", match: :first

    assert_text "Administration was successfully destroyed"
  end
end
