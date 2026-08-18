# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe EE::Integrations::Params, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  let(:controller_class) do
    Class.new(ApplicationController) do
      include Integrations::Params
      include EE::Integrations::Params
    end
  end

  let(:controller) { controller_class.new }
  let(:params) do
    {
      integration: {
        url: 'http://example.com',
        active: true,
        push_events: true,
        jira_check_enabled: 'true',
        jira_exists_check_enabled: 'true',
        jira_assignee_check_enabled: 'false',
        jira_status_check_enabled: 'true',
        jira_allowed_statuses_as_string: 'Ready,In Progress'
      }
    }
  end

  before do
    allow(controller).to receive(:params).and_return(ActionController::Parameters.new(params))
  end

  describe '#integration_params' do
    let(:mock_integration) do
      instance_double(Integration,
        event_channel_names: [],
        event_names: %w[push_events issues_events],
        chat?: false,
        secret_fields: []
      )
    end

    before do
      allow(controller).to receive(:integration).and_return(mock_integration)
    end

    it 'permits Jira verification params' do
      permitted_params = controller.integration_params

      expect(permitted_params[:integration][:jira_check_enabled]).to eq('true')
      expect(permitted_params[:integration][:jira_exists_check_enabled]).to eq('true')
      expect(permitted_params[:integration][:jira_assignee_check_enabled]).to eq('false')
      expect(permitted_params[:integration][:jira_status_check_enabled]).to eq('true')
      expect(permitted_params[:integration][:jira_allowed_statuses_as_string]).to eq('Ready,In Progress')
    end

    it 'includes Jira verification params in ALLOWED_PARAMS_EE constant' do
      expect(EE::Integrations::Params::ALLOWED_PARAMS_EE).to include(
        :jira_check_enabled,
        :jira_exists_check_enabled,
        :jira_assignee_check_enabled,
        :jira_status_check_enabled,
        :jira_allowed_statuses_as_string
      )
    end
  end
end
