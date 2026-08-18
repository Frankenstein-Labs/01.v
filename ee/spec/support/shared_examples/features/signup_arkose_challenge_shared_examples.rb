# frozen_string_literal: true

RSpec.shared_examples 'creates a user with ArkoseLabs risk band' do
  let(:mock_arkose_labs_token) { 'mock_arkose_labs_session_token' }
  let(:mock_arkose_labs_key) { 'private_key' }

  before do
    stub_application_setting(
      arkose_labs_enabled: true,
      arkose_labs_public_api_key: 'public_key',
      arkose_labs_private_api_key: mock_arkose_labs_key
    )

    stub_arkose_token_verification(token_verification_response: :success)

    visit signup_path

    # Since we don't want to execute actual HTTP requests in tests we can't have
    # the frontend show the ArkoseLabs challenge. Instead, we imitate what
    # happens when ArkoseLabs does not show (suppressed: true) the challenge -
    # i.e. the ArkoseLabs session token is assigned as the value of a hidden
    # input field in the signup form.
    selector = '[data-testid="arkose-labs-token-input"]'
    page.execute_script("document.querySelector('#{selector}').value = '#{mock_arkose_labs_token}'")
    page.execute_script("document.querySelector('#{selector}').dispatchEvent(new Event('input'))")
  end

  it 'creates the user', :js do
    fill_and_submit_signup_form

    wait_for_user_to_be_created(user_email)

    created_user = User.find_by_email!(user_email)

    expect(created_user).not_to be_nil

    wait_for('arkose risk band to be recorded') do
      UserCustomAttribute.exists?(user: created_user, key: 'arkose_risk_band')
    end
  end
end
