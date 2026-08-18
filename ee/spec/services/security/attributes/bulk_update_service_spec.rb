# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::BulkUpdateService, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: namespace) }
  let_it_be(:project2) { create(:project, namespace: namespace) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be(:subproject) { create(:project, namespace: subgroup) }
  let_it_be(:root_namespace) { namespace.root_ancestor }

  let_it_be(:category) { create(:security_category, namespace: root_namespace, name: 'Test Category') }
  let_it_be(:attribute1) do
    create(:security_attribute, security_category: category, name: 'Critical', namespace: root_namespace)
  end

  let_it_be(:attribute2) do
    create(:security_attribute, security_category: category, name: 'High', namespace: root_namespace)
  end

  let(:group_ids) { [] }
  let(:project_ids) { [project1.id, project2.id] }
  let(:attribute_ids) { [attribute1.id, attribute2.id] }
  let(:mode) { :add }
  let(:current_user) { user }

  let(:service) do
    described_class.new(
      group_ids: group_ids,
      project_ids: project_ids,
      attribute_ids: attribute_ids,
      mode: mode,
      current_user: current_user
    )
  end

  describe '#execute' do
    before_all do
      namespace.add_maintainer(user)
    end

    context 'with valid parameters' do
      it 'schedules scheduler worker for processing' do
        expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
          .with(group_ids, project_ids, attribute_ids, 'add', user.id)

        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Bulk update operation initiated')
      end
    end

    context 'with groups in items' do
      let(:group_ids) { [namespace.id] }
      let(:project_ids) { [] }

      it 'schedules scheduler worker with group IDs' do
        expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
          .with(group_ids, project_ids, attribute_ids, 'add', user.id)

        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Bulk update operation initiated')
      end
    end

    context 'with mixed groups and projects' do
      let(:group_ids) { [namespace.id] }
      let(:project_ids) { [project1.id] }

      it 'schedules scheduler worker with separated IDs' do
        expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
          .with(group_ids, project_ids, attribute_ids, 'add', user.id)

        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq('Bulk update operation initiated')
      end
    end

    context 'with REMOVE mode' do
      let(:mode) { :remove }

      it 'passes correct mode to scheduler worker' do
        expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
          .with(group_ids, project_ids, attribute_ids, 'remove', user.id)

        result = service.execute

        expect(result).to be_success
      end
    end

    context 'with REPLACE mode' do
      let(:mode) { :replace }

      it 'passes correct mode to scheduler worker' do
        expect(Security::Attributes::BulkUpdateSchedulerWorker).to receive(:perform_async)
          .with(group_ids, project_ids, attribute_ids, 'replace', user.id)

        result = service.execute

        expect(result).to be_success
      end
    end
  end
end
