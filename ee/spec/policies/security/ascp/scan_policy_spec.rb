# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::ScanPolicy, feature_category: :static_application_security_testing do
  include PolicyHelpers
  include AdminModeHelper

  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :private) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:owner) { create(:user, owner_of: project) }
  let_it_be(:planner) { create(:user, planner_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }
  let_it_be(:auditor) { create(:user, :auditor) }
  let_it_be(:non_member) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  subject { described_class.new(user, scan) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe 'read_ascp_scan' do
    let(:policy) { :read_ascp_scan }

    where(:role, :allowed) do
      :guest      | false
      :planner    | false
      :reporter   | false
      :non_member | false
      :developer  | true
      :maintainer | true
      :auditor    | true
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

  describe 'create_ascp_scan' do
    let(:policy) { :create_ascp_scan }

    where(:role, :allowed) do
      :guest      | false
      :planner    | false
      :reporter   | false
      :non_member | false
      :developer  | false
      :maintainer | true
      :auditor    | false
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
