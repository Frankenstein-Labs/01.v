# frozen_string_literal: true

RSpec::Matchers.define :render_lead_form do
  match do |response|
    expect(response).to have_gitlab_http_status(:ok)

    expect(response.body).to include(s_('DuoProTrial|Start your free GitLab Duo Pro trial'))

    expect(response.body).to include(s_('DuoProTrial|We just need some additional information to activate your trial.'))
  end
end

RSpec::Matchers.define :render_select_namespace_duo do
  match do |response|
    expect(response).to have_gitlab_http_status(:ok)

    expect(response.body).to include(s_('DuoProTrial|Apply your GitLab Duo Pro trial to an existing group'))
  end
end

RSpec::Matchers.define :redirect_to_sign_in do
  match do |response|
    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to include('Sign in or sign up before continuing')
  end
end

RSpec::Matchers.define :render_lead_form_duo_enterprise do
  match do |response|
    expect(response).to have_gitlab_http_status(:ok)

    expect(response.body).to include(s_('DuoEnterpriseTrial|Start your free GitLab Duo Enterprise trial'))

    expect(response.body)
      .to include(s_('DuoEnterpriseTrial|We just need some additional information to activate your trial.'))
  end
end

RSpec::Matchers.define :render_select_namespace_duo_enterprise do
  match do |response|
    expect(response).to have_gitlab_http_status(:ok)

    expect(response.body)
      .to include(s_('DuoEnterpriseTrial|Apply your GitLab Duo Enterprise trial to an existing group'))
  end
end
