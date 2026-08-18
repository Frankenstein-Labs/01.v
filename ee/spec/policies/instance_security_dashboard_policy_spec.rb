# frozen_string_literal: true

require 'spec_helper'

RSpec.describe InstanceSecurityDashboardPolicy do
  let(:current_user) { create(:user) }
  let(:user) { create(:user) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  subject { described_class.new(current_user, [user]) }

  describe 'read_instance_security_dashboard' do
    let(:abilities) { %i[read_instance_security_dashboard read_security_resource] }

    context 'when the user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.not_to be_allowed(*abilities) }
    end

    context 'when the user is logged in' do
      it { is_expected.to be_allowed(*abilities) }
    end
  end

  describe 'create_vulnerability_export' do
    context 'when the user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.not_to be_allowed(:create_vulnerability_export) }
    end

    context 'when the user is logged in' do
      it { is_expected.to be_allowed(:create_vulnerability_export) }
    end
  end

  describe 'read_cluster' do
    context 'when the user is not logged in' do
      let(:current_user) { nil }

      it { is_expected.not_to be_allowed(:read_cluster) }
    end

    context 'when the user is logged in' do
      it { is_expected.to be_allowed(:read_cluster) }
    end
  end

  describe 'resolve_vulnerability_with_ai' do
    using RSpec::Parameterized::TableSyntax

    subject { described_class.new(current_user, InstanceSecurityDashboard.new(current_user)) }

    let_it_be_with_reload(:project) do
      create(:project, :with_duo_features_disabled, namespace: create(:group))
    end

    let_it_be(:guest) { create(:user, guest_of: project) }
    let_it_be(:developer) { create(:user, developer_of: project) }

    before do
      stub_licensed_features(
        security_dashboard: true,
        ai_features: true
      )

      allow(developer).to receive(:allowed_to_use?).and_return(true)
      allow(guest).to receive(:allowed_to_use?).and_return(true)
    end

    context 'when user cannot :read_security_resource' do
      let(:current_user) { guest }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_disallowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          project.project_setting.update!(duo_features_enabled: duo_features_enabled)
          current_user.security_dashboard_projects << project
        end

        it { is_expected.to cs_matcher }
      end
    end

    context 'when user can?(:read_security_resource)' do
      let(:current_user) { developer }

      where(:duo_features_enabled, :cs_matcher) do
        true  | be_allowed(:resolve_vulnerability_with_ai)
        false | be_disallowed(:resolve_vulnerability_with_ai)
      end

      with_them do
        before do
          project.project_setting.update!(duo_features_enabled: duo_features_enabled)
          current_user.security_dashboard_projects << project
        end

        it { is_expected.to cs_matcher }
      end
    end
  end
end
