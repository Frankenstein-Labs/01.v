# frozen_string_literal: true

# Requires the including spec to define:
# - `registration_path`: the path to POST the registration request to
# - `registration_params`: the params hash to POST (including the `user:` key)
# - `submitted_email`: the email address submitted in `registration_params`, used to look up the created user
RSpec.shared_examples 'bypasses email confirmation for the QA user agent on staging' do
  let(:qa_user_agent) { 'qa-browser-agent' }
  let(:user_agent) { qa_user_agent }

  subject(:create_user) do
    post registration_path, params: registration_params, headers: { 'HTTP_USER_AGENT' => user_agent }
  end

  before do
    stub_config_setting(url: ::Gitlab.staging_com_url)
    stub_env('GITLAB_QA_USER_AGENT', qa_user_agent)
    stub_application_setting_enum('email_confirmation_setting', 'hard')
    stub_application_setting(require_admin_approval_after_user_signup: false)
    stub_saas_features(identity_verification: true)
  end

  it 'confirms the user and does not redirect to identity verification', :aggregate_failures do
    allow(::Gitlab::AppLogger).to receive(:info).and_call_original

    create_user

    expect(User.find_by(email: submitted_email)).to be_confirmed
    expect(response).not_to redirect_to(signup_identity_verification_path)
    expect(::Gitlab::AppLogger).to have_received(:info).with(
      hash_including(
        message: 'Bypassed email confirmation for QA user agent on staging',
        Labkit::Fields::GL_USER_NAME => registration_params[:user][:username],
        Labkit::Fields::REMOTE_IP => '127.0.0.1'
      )
    )
  end

  context 'when not on staging' do
    before do
      stub_config_setting(url: ::Gitlab.com_url)
    end

    it 'does not confirm the user and still redirects to identity verification', :aggregate_failures do
      create_user

      expect(User.find_by(email: submitted_email)).not_to be_confirmed
      expect(response).to redirect_to(signup_identity_verification_path)
    end
  end

  context 'when the user agent does not match GITLAB_QA_USER_AGENT' do
    let(:user_agent) { 'not-the-qa-agent' }

    it 'does not confirm the user and still redirects to identity verification', :aggregate_failures do
      create_user

      expect(User.find_by(email: submitted_email)).not_to be_confirmed
      expect(response).to redirect_to(signup_identity_verification_path)
    end
  end
end
