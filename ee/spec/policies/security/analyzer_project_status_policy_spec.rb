# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerProjectStatusPolicy, feature_category: :security_asset_inventories do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:analyzer_status) do
    build(:analyzer_project_status, status: :success,
      analyzer_type: :sast, project: project)
  end

  subject { described_class.new(user, analyzer_status) }

  context 'when the security_dashboard feature is enabled' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the current user has maintainer access to the project' do
      before_all do
        project.add_maintainer(user)
      end

      it { is_expected.to be_allowed(:read_security_inventory) }
    end

    context 'when the current user has developer access to the project' do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.to be_allowed(:read_security_inventory) }
    end

    context 'when the current user does not have developer access to the project' do
      it { is_expected.to be_disallowed(:read_security_inventory) }
    end
  end

  context 'when the security_dashboard feature is disabled' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    it { is_expected.to be_disallowed(:read_security_inventory) }
  end
end
