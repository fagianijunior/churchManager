require "application_system_test_case"

class ChurchesTest < ApplicationSystemTestCase
  setup do
    @church = churches(:one)
  end

  test "visiting the index" do
    visit churches_url
    assert_selector "h1", text: "Churches"
  end

  test "should create church" do
    visit churches_url
    click_on "New church"

    fill_in "Fundation date", with: @church.fundation_date
    fill_in "Name", with: @church.name
    click_on "Create Church"

    assert_text "Church was successfully created"
    click_on "Back"
  end

  test "should update Church" do
    visit church_url(@church)
    click_on "Edit this church", match: :first

    fill_in "Fundation date", with: @church.fundation_date
    fill_in "Name", with: @church.name
    click_on "Update Church"

    assert_text "Church was successfully updated"
    click_on "Back"
  end

  test "should destroy Church" do
    visit church_url(@church)
    click_on "Destroy this church", match: :first

    assert_text "Church was successfully destroyed"
  end
end
