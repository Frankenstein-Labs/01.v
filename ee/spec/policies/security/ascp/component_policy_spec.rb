# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::ComponentPolicy, feature_category: :static_application_security_testing do
  include PolicyHelpers
  include AdminModeHelper

  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :private) }
  let_it_be(:component) { create(:security_ascp_component, project: project) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:owner) { create(:user, owner_of: project) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  subject { described_class.new(user, component) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'read_ascp_component' do
    let(:policy) { :read_ascp_component }

    where(:role, :allowed) do
      :guest      | false
      :non_member | false
      :developer  | true
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:user) { public_send(role) }

      before do
        enable_admin_mode!(user) if role == :admin
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end

    context 'when user is nil' do
      let(:user) { nil }

      it { expect_disallowed(policy) }
    end

    context 'when security_dashboard is not licensed' do
      let(:user) { developer }

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it { expect_disallowed(policy) }
    end
  end

  describe 'create_ascp_component' do
    let(:policy) { :create_ascp_component }

    where(:role, :allowed) do
      :guest      | false
      :non_member | false
      :developer  | false
      :maintainer | true
      :owner      | true
      :admin      | true
    end

    with_them do
      let(:user) { public_send(role) }

      before do
        enable_admin_mode!(user) if role == :admin
      end

      it { is_expected.to(allowed ? be_allowed(policy) : be_disallowed(policy)) }
    end

    context 'when user is nil' do
      let(:user) { nil }

      it { expect_disallowed(policy) }
    end

    context 'when security_dashboard is not licensed' do
      let(:user) { maintainer }

      before do
        stub_licensed_features(security_dashboard: false)
      end

      it { expect_disallowed(policy) }
    end
  end
end
