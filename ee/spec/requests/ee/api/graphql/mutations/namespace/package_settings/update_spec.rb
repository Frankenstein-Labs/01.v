# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating the package settings', feature_category: :package_registry do
  include GraphqlHelpers

  let_it_be_with_reload(:namespace) { create(:group) }
  let_it_be(:user) { create(:user, owner_of: namespace) }

  let(:params) do
    {
      namespace_path: namespace.full_path,
      audit_events_enabled: true
    }
  end

  let(:mutation) do
    graphql_mutation(:update_namespace_package_settings, params) do
      <<~QL
        packageSettings {
          auditEventsEnabled
        }
        errors
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:update_namespace_package_settings) }
  let(:package_settings_response) { mutation_response['packageSettings'] }

  RSpec.shared_examples 'returning a success' do
    it_behaves_like 'returning response status', :success

    it 'returns the updated package settings', :aggregate_failures do
      subject

      expect(mutation_response['errors']).to be_empty
      expect(package_settings_response['auditEventsEnabled']).to eq(params[:audit_events_enabled])
    end
  end

  describe 'post graphql mutation' do
    subject { post_graphql_mutation(mutation, current_user: user) }

    context 'with existing package settings' do
      let_it_be(:package_settings) { create(:namespace_package_setting, namespace: namespace) }

      it_behaves_like 'updating the namespace package setting attributes',
        from: { audit_events_enabled: false }, to: { audit_events_enabled: true }

      it_behaves_like 'returning a success'
    end

    context 'without existing package settings' do
      let(:package_settings) { namespace.package_settings }

      it_behaves_like 'creating the namespace package setting'
    end
  end
end
