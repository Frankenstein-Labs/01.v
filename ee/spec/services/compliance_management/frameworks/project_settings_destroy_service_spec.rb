# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::ProjectSettingsDestroyService, feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: "Framework 1") }
  let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: "Framework 2") }
  let_it_be(:framework3) { create(:compliance_framework, namespace: group, name: "Framework 3") }

  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:project3) { create(:project, group: group) }

  let(:namespace_id) { nil }

  let(:service) { described_class.new(framework_ids:, namespace_id:) }

  before_all do
    create(:compliance_framework_project_setting, project: project1, compliance_management_framework: framework1)
    create(:compliance_framework_project_setting, project: project2, compliance_management_framework: framework1)

    create(:compliance_framework_project_setting, project: project3, compliance_management_framework: framework2)
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'with a single framework_id' do
      let(:framework_ids) { [framework1.id] }

      it 'deletes all project settings for the framework and returns success response', :aggregate_failures do
        expect { execute }.to change {
          ComplianceManagement::ComplianceFramework::ProjectSettings.where(framework_id: framework_ids).size
        }.by(-2)

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 2 }
        )
      end

      it 'does not delete project settings for other frameworks' do
        expect do
          service.execute
        end.not_to change {
          ComplianceManagement::ComplianceFramework::ProjectSettings.where(framework_id: framework2.id).count
        }
      end
    end

    context 'with multiple framework_ids' do
      let(:framework_ids) { [framework1.id, framework2.id] }

      it 'deletes project settings for all specified frameworks and returns success response', :aggregate_failures do
        expect { execute }.to change {
          ComplianceManagement::ComplianceFramework::ProjectSettings.count
        }.by(-3)

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 3 }
        )
      end
    end

    context 'with a namespace_id' do
      let(:namespace_id) { group.id }
      let(:framework_ids) { nil }

      it 'deletes project settings for all specified frameworks and returns success response', :aggregate_failures do
        expect { execute }.to change {
          ComplianceManagement::ComplianceFramework::ProjectSettings.count
        }.by(-3)

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 3 }
        )
      end

      context 'when namespace has no frameworks' do
        let(:empty_group) { create(:group) }
        let(:namespace_id) { empty_group.id }

        it 'returns success with zero deleted count' do
          expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }

          is_expected.to be_success.and have_attributes(
            payload: { deleted_count: 0 }
          )
        end
      end
    end

    context 'with non-existent namespace_id' do
      let(:namespace_id) { non_existing_record_id }
      let(:framework_ids) { nil }

      it 'does not delete any existing project settings and returns success response', :aggregate_failures do
        expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 0 }
        )
      end
    end

    context 'with non-existent framework_id' do
      let(:framework_ids) { [non_existing_record_id] }

      it 'does not delete any existing project settings and returns success response', :aggregate_failures do
        expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 0 }
        )
      end
    end

    context 'with empty framework_ids array' do
      let(:framework_ids) { [] }

      it 'returns success response with zero deleted count', :aggregate_failures do
        expect { execute }.not_to change { ComplianceManagement::ComplianceFramework::ProjectSettings.count }

        is_expected.to be_success.and have_attributes(
          message: 'Destroyed related project settings for frameworks',
          payload: { deleted_count: 0 }
        )
      end
    end

    context 'when an error occurs' do
      let(:framework_ids) { [framework1.id] }

      before do
        allow(ComplianceManagement::ComplianceFramework::ProjectSettings)
          .to receive(:delete_by_framework)
          .and_raise(StandardError, 'Database connection error')
      end

      it 'returns the correct error response and does not raise an exception' do
        expect { execute }.not_to raise_error

        is_expected.to be_error.and have_attributes(
          message: 'Failed to delete project settings for frameworks: Database connection error'
        )
      end
    end
  end
end
