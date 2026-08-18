# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'help/instance_configuration', feature_category: :configuration do
  describe 'Rate Limits (EE)' do
    let(:instance_configuration) { build(:instance_configuration) }
    let(:settings) { instance_configuration.settings }
    let(:rate_limits) { settings[:rate_limits] }

    before do
      assign(:instance_configuration, instance_configuration)
    end

    context 'when incident_management_notification rate limit is present' do
      before do
        Gitlab::CurrentSettings.current_application_settings.update!(
          throttle_incident_management_notification_enabled: true,
          throttle_incident_management_notification_per_period: 3601,
          throttle_incident_management_notification_period_in_seconds: 3600
        )
      end

      context 'when signed in' do
        let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Persisted user needed for sign_in

        before do
          sign_in(user)
        end

        it 'displays incident management inbound alert rate limit' do
          render
          expect(rendered).to include(
            "<td>Incident management inbound alert requests</td>\n<td>3601</td>\n<td>3600</td>"
          )
        end
      end

      context 'when signed out' do
        it 'does not display incident management inbound alert rate limits' do
          render
          expect(rendered).not_to have_content('Incident management inbound alert requests')
        end
      end
    end
  end
end
