# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::Protection::CreateTagRuleService, feature_category: :container_registry do
  include ContainerRegistryHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project: project, current_user: current_user, params: params) }

  subject(:service_execute) { service.execute }

  before do
    stub_gitlab_api_client_to_support_gitlab_api(supported: true)
  end

  context 'when creating immutable protection rules' do
    let(:params) { attributes_for(:container_registry_protection_tag_rule, :immutable, project: project) }

    shared_examples 'a successful immutable rule creation' do
      it_behaves_like 'returning a success service response' do
        it 'returns the created immutable rule with the correct attributes' do
          is_expected.to be_success.and have_attributes(
            payload: {
              container_protection_tag_rule:
              be_a(::ContainerRegistry::Protection::TagRule)
              .and(have_attributes(
                tag_name_pattern: params[:tag_name_pattern],
                minimum_access_level_for_push: nil,
                minimum_access_level_for_delete: nil
              ))
            }
          )
        end
      end

      it 'creates a new immutable container registry tag protection rule in the database' do
        expect { subject }.to change {
          ::ContainerRegistry::Protection::TagRule.where(
            project: project,
            tag_name_pattern: params[:tag_name_pattern]
          ).count
        }.by(1)
      end
    end

    shared_examples 'an erroneous immutable rule creation' do |message:|
      it_behaves_like 'returning an error service response', message: message do
        it { is_expected.to be_error.and have_attributes(payload: include(container_protection_tag_rule: nil)) }
      end

      it 'does not create a new container registry tag protection rule in the database' do
        expect { subject }.not_to change { ContainerRegistry::Protection::TagRule.count }
      end
    end

    context 'when license for container_registry_immutable_tag_rules is enabled' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      context 'when the user is an admin', :enable_admin_mode do
        let(:current_user) { build_stubbed(:admin) }

        it_behaves_like 'a successful immutable rule creation'
      end

      context 'when the user is an owner' do
        it_behaves_like 'a successful immutable rule creation'
      end

      context 'when the user is not an owner nor an admin' do
        let_it_be(:current_user) { create(:user, maintainer_of: project) }

        it_behaves_like 'an erroneous immutable rule creation',
          message: 'Unauthorized to create an immutable protection rule for container image tags'
      end
    end

    context 'when license for container_registry_immutable_tag_rules is disabled' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: false)
      end

      it_behaves_like 'an erroneous immutable rule creation', message: 'Immutable tag rules require an Ultimate license'
    end

    context 'when tracking internal events' do
      before do
        stub_licensed_features(container_registry_immutable_tag_rules: true)
      end

      it 'tracks the create_container_registry_protected_tag_rule event' do
        expect { service_execute }
          .to trigger_internal_events('create_container_registry_protected_tag_rule')
          .with(
            project: project,
            namespace: project.namespace,
            user: current_user,
            additional_properties: { rule_type: 'immutable' }
          )
          .once
      end

      context 'when rule creation fails' do
        before do
          allow_next_instance_of(ContainerRegistry::Protection::TagRule) do |instance|
            allow(instance).to receive_messages(
              save: false,
              persisted?: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['Validation error'])
            )
          end
        end

        it 'does not track the event' do
          expect { service_execute }.not_to trigger_internal_events('create_container_registry_protected_tag_rule')
        end
      end
    end
  end
end
