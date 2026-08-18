# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::DeleteTagRuleService, '#execute', feature_category: :container_registry do
  include ContainerRegistryHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be_with_refind(:container_protection_tag_rule) do
    create(:container_registry_protection_tag_rule, :immutable, project: project)
  end

  subject(:service_execute) do
    described_class.new(container_protection_tag_rule, current_user: current_user).execute
  end

  before do
    stub_gitlab_api_client_to_support_gitlab_api(supported: true)
  end

  context 'when tracking internal events' do
    context 'with immutable tag rule' do
      it 'tracks the delete_container_registry_protected_tag_rule event with immutable rule_type' do
        expect { service_execute }
          .to trigger_internal_events('delete_container_registry_protected_tag_rule')
          .with(
            project: project,
            namespace: project.namespace,
            user: current_user,
            additional_properties: { rule_type: 'immutable' }
          )
          .once
      end
    end
  end
end
