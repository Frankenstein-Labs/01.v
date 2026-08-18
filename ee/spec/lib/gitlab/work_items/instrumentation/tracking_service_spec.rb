# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::WorkItems::Instrumentation::TrackingService, feature_category: :portfolio_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: user) }
  let_it_be(:work_item) { create(:work_item, project: project) }

  let(:service) { described_class.new(**service_params) }
  let(:service_params) { base_params.merge(additional_params) }
  let(:base_params) { { work_item: work_item, current_user: user } }

  describe '#execute', :clean_gitlab_redis_shared_state do
    context 'when extra_properties are provided' do
      let(:additional_params) do
        {
          event: ::Gitlab::WorkItems::Instrumentation::EventActions::AGENT_PLAN_CREATE,
          extra_properties: { source: 'ai_workflows' }
        }
      end

      let(:expected_properties_with_extras) do
        {
          user: user,
          project: project,
          namespace: project.project_namespace,
          additional_properties: {
            label: work_item.work_item_type.name,
            property: "Developer",
            source: 'ai_workflows'
          }
        }
      end

      it 'merges them into additional_properties' do
        expect { service.execute }
          .to trigger_internal_events('work_item_agent_plan_create')
          .with(expected_properties_with_extras)
      end
    end
  end
end
