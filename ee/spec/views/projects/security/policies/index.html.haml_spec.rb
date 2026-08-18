# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projects/security/policies/index", feature_category: :security_policy_management, type: :view do
  let(:user) { project.first_owner }
  let(:project) { create(:project) }

  before do
    sign_in(user)
    render template: 'projects/security/policies/index', locals: { project: project }
  end

  it 'renders the security policies list root' do
    expect(rendered).to have_selector('#js-security-policies-list')
  end

  it 'passes the namespace path as a data attribute' do
    expect(rendered).to have_selector(
      "#js-security-policies-list[data-namespace-path='#{project.full_path}']"
    )
  end
end
