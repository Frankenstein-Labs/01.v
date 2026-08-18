# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::ExportService, feature_category: :compliance_management do
  subject(:service) { described_class.new user: user, group: group }

  let_it_be(:csv_header) { "Name,Associated Projects" }
  let_it_be(:user) { create :user, name: 'Rick Sanchez' }

  let_it_be_with_reload(:group) { create :group, name: 'parent' }
  let_it_be(:sub_group) { create :group, name: 'sub_lvl_1', parent: group }
  let_it_be(:sub_sub_group) { create :group, name: 'sub_lvl_2', parent: sub_group }

  let_it_be(:project_0) do
    create :project, :repository, namespace: group, name: 'parent_project', path: 'parent_project'
  end

  let_it_be(:project_1) do
    create :project, :repository, namespace: sub_group, name: 'sub_group_project', path: 'sub_group_project'
  end

  let_it_be(:project_2) do
    create :project, :repository, namespace: sub_sub_group, name: 'sub_sub_group_project', path: 'sub_sub_group_project'
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  describe "#execute" do
    context 'with a authorized user' do
      before_all do
        group.add_owner user
      end

      context 'with no frameworks' do
        it { expect(service.execute).to be_success }

        it 'exports a CSV payload with only the header' do
          export = <<~EXPORT
          #{csv_header}
          EXPORT

          expect(service.execute.payload[:csv]).to eq export
          expect(service.execute.payload[:truncated]).to be false
        end
      end

      context 'with frameworks assigned' do
        let_it_be(:fedramp_framework) { create :compliance_framework, name: 'FedRamp', namespace: group }
        let_it_be(:gdpr_framework) { create :compliance_framework, namespace: group }

        before do
          group.namespace_settings.update! default_compliance_framework_id: gdpr_framework.id
          create(
            :compliance_framework_project_setting,
            project: project_0,
            compliance_management_framework: fedramp_framework
          )
          create(
            :compliance_framework_project_setting,
            project: project_1,
            compliance_management_framework: gdpr_framework
          )
        end

        it 'exports a CSV payload with frameworks' do
          export = <<~EXPORT
          #{csv_header}
          FedRamp,parent_project
          GDPR,sub_group_project
          EXPORT

          expect(service.execute.payload[:csv]).to eq export
          expect(service.execute.payload[:truncated]).to be false
        end
      end
    end
  end

  describe '#email_export' do
    subject(:service) { described_class.new user: user, group: group }

    let(:worker) { ComplianceManagement::FrameworkExportMailerWorker }

    it 'enqueues a worker' do
      expect(worker).to receive(:perform_async).with(user.id, group.id)

      expect(service.email_export).to be_success
    end
  end
end
