# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Policies::DependencyProxy::GroupPolicy, feature_category: :container_registry do
  include_context 'GroupPolicy context'

  subject do
    described_class.new(auth_token, group.dependency_proxy_for_containers_policy_subject)
  end

  let_it_be(:current_user) { guest }
  let_it_be(:auth_token) { create(:personal_access_token, user: current_user) }

  before do
    stub_config(dependency_proxy: { enabled: true }, registry: { enabled: true })
  end

  context 'when there is no active sso session' do
    before do
      allow(::Gitlab::Auth::GroupSaml::SsoEnforcer)
        .to receive(:access_restricted?)
        .and_return(true)
    end

    it { expect_disallowed(:read_group) }
  end
end
