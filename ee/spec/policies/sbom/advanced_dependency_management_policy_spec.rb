# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::AdvancedDependencyManagementPolicy, feature_category: :dependency_management do
  describe 'read_advanced_dependency_management' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:guest) { create(:user, guest_of: group) }
    let_it_be(:developer) { create(:user, developer_of: group) }

    let(:es_allowed) { true }

    before do
      stub_licensed_features(dependency_scanning: true)
      allow(::Search::Elastic::SbomOccurrenceRefIndexHelper)
        .to receive(:advanced_dependency_management_allowed?).and_return(es_allowed)
    end

    shared_examples 'gating advanced dependency management' do
      context 'when the user can read dependencies and advanced dependency management is allowed' do
        let(:user) { developer }

        it { expect_allowed(:read_advanced_dependency_management) }
      end

      context 'when advanced dependency management is not allowed' do
        let(:user) { developer }
        let(:es_allowed) { false }

        it { expect_disallowed(:read_advanced_dependency_management) }
      end

      context 'when the role does not grant the permission' do
        let(:user) { guest }

        it { expect_disallowed(:read_advanced_dependency_management) }
      end

      context 'when the user is anonymous' do
        let(:user) { nil }

        it { expect_disallowed(:read_advanced_dependency_management) }
      end

      context 'when dependency scanning is not licensed' do
        let(:user) { developer }

        before do
          stub_licensed_features(dependency_scanning: false)
        end

        it { expect_disallowed(:read_advanced_dependency_management) }
      end
    end

    context 'for a group' do
      subject(:policy) { GroupPolicy.new(user, group) }

      it_behaves_like 'gating advanced dependency management'
    end

    context 'for a project' do
      subject(:policy) { ProjectPolicy.new(user, project) }

      it_behaves_like 'gating advanced dependency management'
    end
  end
end
