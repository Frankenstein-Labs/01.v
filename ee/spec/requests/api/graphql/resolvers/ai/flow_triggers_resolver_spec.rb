# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::FlowTriggersResolver, :with_current_organization, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: maintainer) }
  let_it_be(:triggers) { create_list(:ai_flow_trigger, 3, project: project) }
  let_it_be(:other_project) { create(:project, maintainers: maintainer) }
  let_it_be(:other_trigger) { create(:ai_flow_trigger, project: other_project) }
  let_it_be(:subscription_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_core, :self_managed) }

  let(:nodes) { graphql_data_at(:project, :ai_flow_triggers, :nodes) }
  let(:current_user) { maintainer }
  let(:args) { '' }

  let(:query) do
    <<~GQL
      {
        project(fullPath: "#{project.full_path}") {
          aiFlowTriggers#{args} {
            nodes {
              id
            }
          }
        }
      }
    GQL
  end

  before do
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
    ::Ai::Setting.for_organization(current_organization).update!(duo_core_features_enabled: true)
    stub_ee_application_setting(duo_features_enabled: true)
  end

  context 'when developer' do
    let(:current_user) do
      create(:user).tap { |user| project.add_reporter(user) }
    end

    it 'returns no flow triggers' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to be_empty
    end
  end

  it 'returns all flow triggers for project' do
    post_graphql(query, current_user: current_user)

    expect(nodes).to match_array(
      triggers.map { |trigger| a_graphql_entity_for(trigger) }
    )
  end

  describe 'configUrl field' do
    let_it_be(:project_with_repo) { create(:project, :in_group, :repository, maintainers: maintainer) }

    let(:query) do
      <<~GQL
        {
          project(fullPath: "#{project_with_repo.full_path}") {
            aiFlowTriggers {
              nodes {
                configUrl
              }
            }
          }
        }
      GQL
    end

    context 'when the trigger has a config_path and the project has a repository' do
      let_it_be(:trigger_with_config) do
        create(:ai_flow_trigger, project: project_with_repo, config_path: 'path/to/config.yml')
      end

      it 'returns the blob URL for the config file' do
        post_graphql(query, current_user: current_user)

        config_url = graphql_data_at(:project, :ai_flow_triggers, :nodes).first['configUrl']
        expect(config_url).to include(project_with_repo.default_branch, 'path/to/config.yml')
      end
    end

    context 'when config_path is nil (catalog mode trigger)' do
      let_it_be(:catalog_item) { create(:ai_catalog_flow) }
      let_it_be(:item_consumer) do
        create(:ai_catalog_item_consumer, :child_item_consumer, project: project_with_repo, item: catalog_item)
      end

      let_it_be(:trigger_catalog_mode) do
        create(
          :ai_flow_trigger, :for_catalog_consumer, project: project_with_repo, ai_catalog_item_consumer: item_consumer
        )
      end

      it 'returns nil' do
        post_graphql(query, current_user: current_user)

        config_url = graphql_data_at(:project, :ai_flow_triggers, :nodes).first['configUrl']
        expect(config_url).to be_nil
      end
    end

    # Empty string config_path can exist in legacy DB records but fails model validation,
    # so config_path must be stubbed rather than persisted directly.
    context 'when config_path is an empty string' do
      let_it_be(:trigger_empty_path) { create(:ai_flow_trigger, project: project_with_repo) }

      before do
        allow_next_found_instance_of(Ai::FlowTrigger) do |trigger|
          allow(trigger).to receive(:config_path).and_return('')
        end
      end

      it 'returns nil' do
        post_graphql(query, current_user: current_user)

        config_url = graphql_data_at(:project, :ai_flow_triggers, :nodes).first['configUrl']
        expect(config_url).to be_nil
      end
    end

    context 'when the project has no repository' do
      let_it_be(:empty_project) { create(:project_empty_repo, maintainers: maintainer) }
      let_it_be(:trigger_no_repo) do
        create(:ai_flow_trigger, project: empty_project, config_path: 'path/to/config.yml')
      end

      let(:query) do
        <<~GQL
          {
            project(fullPath: "#{empty_project.full_path}") {
              aiFlowTriggers {
                nodes {
                  configUrl
                }
              }
            }
          }
        GQL
      end

      it 'returns nil' do
        post_graphql(query, current_user: current_user)

        config_url = graphql_data_at(:project, :ai_flow_triggers, :nodes).first['configUrl']
        expect(config_url).to be_nil
      end
    end
  end

  context 'when ids argument present' do
    let(:args) do
      <<~GQL
        (ids: [
          "#{triggers[0].to_global_id}",
          "#{triggers[1].to_global_id}",
          "#{other_trigger.to_global_id}"
        ])
      GQL
    end

    it 'returns flow triggers for project with ids' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to contain_exactly(a_graphql_entity_for(triggers[0]), a_graphql_entity_for(triggers[1]))
    end
  end
end
