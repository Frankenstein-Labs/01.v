# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::TypesFinder, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:group_project) { create(:project, group: group) }
  let_it_be(:system_defined_work_item_type) { build(:work_item_system_defined_type, :issue) }
  let_it_be(:custom_work_item_type) do
    create(:work_item_custom_type, :with_organization, organization: group.organization)
  end

  subject(:finder) { described_class.new(container: container) }

  context 'when the container is a project in group namespace' do
    let(:container) { group_project }

    context 'with custom work item types' do
      it 'includes both system-defined and custom work item types' do
        result = finder.execute

        expect(result).to include(system_defined_work_item_type, custom_work_item_type)
      end
    end

    context 'with only_available: true and multiple custom types sharing the same base type' do
      # Regression test for https://gitlab.com/gitlab-org/gitlab/-/work_items/595284
      let_it_be(:converted_issue_type) do
        create(:work_item_custom_type, :converted_from_issue, :with_organization, organization: group.organization,
          name: 'Converted Issue')
      end

      let_it_be(:feature_request_type) do
        create(:work_item_custom_type, :with_organization, organization: group.organization, name: 'Feature Request')
      end

      let_it_be(:access_request_type) do
        create(:work_item_custom_type, :with_organization, organization: group.organization, name: 'Access Request')
      end

      it 'returns each custom type exactly once without the system-defined issue type' do
        result = finder.execute(only_available: true)

        expect(result).to eq(result.uniq)
        expect(result).to include(converted_issue_type, feature_request_type, access_request_type)
        expect(result).not_to include(system_defined_work_item_type)
      end

      context 'when filtering by name with multiple same-base-type custom types' do
        it 'returns each matching type exactly once' do
          result = finder.execute(name: 'issue', only_available: true)

          expect(result).to eq(result.uniq)
        end
      end
    end
  end

  context 'when the container is a group' do
    let(:container) { group }

    context 'with custom work item types' do
      it 'includes both system-defined and custom work item types' do
        result = finder.execute

        expect(result).to include(system_defined_work_item_type, custom_work_item_type)
      end
    end
  end
end
