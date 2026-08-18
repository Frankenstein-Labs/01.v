# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::OrbitHelper, feature_category: :knowledge_graph do
  describe '#orbit_app_data' do
    before do
      # current_user goes through Devise/Warden which is not wired up for
      # helper specs; stub the helper-level methods that depend on it.
      allow(helper).to receive_messages(current_user: nil, duo_accessible?: false,
        orbit_settings_enabled?: false, admin_orbit_configure_available?: false,
        saas_orbit_configure_available?: false)
    end

    it 'includes router_base pointing at the dashboard orbit path' do
      expect(helper.orbit_app_data[:router_base]).to eq(dashboard_orbit_path)
    end

    it 'includes duo_accessible as a string' do
      expect(helper.orbit_app_data[:duo_accessible]).to eq('false')
    end

    it 'includes orbit_settings_enabled as a string' do
      expect(helper.orbit_app_data[:orbit_settings_enabled]).to eq('false')
    end

    context 'when admin orbit configure is available' do
      before do
        allow(helper).to receive(:admin_orbit_configure_available?).and_return(true)
      end

      it 'sets configure_mode to admin and includes the admin path' do
        data = helper.orbit_app_data

        expect(data[:configure_mode]).to eq('admin')
        expect(data[:admin_configuration_path]).to eq(admin_orbit_path)
      end
    end

    context 'when saas orbit configure is available' do
      before do
        allow(helper).to receive_messages(
          admin_orbit_configure_available?: false,
          saas_orbit_configure_available?: true
        )
      end

      it 'sets configure_mode to groups without an admin path' do
        data = helper.orbit_app_data

        expect(data[:configure_mode]).to eq('groups')
        expect(data).not_to have_key(:admin_configuration_path)
      end
    end

    context 'when neither configure mode applies' do
      it 'omits configure_mode entirely' do
        expect(helper.orbit_app_data).not_to have_key(:configure_mode)
      end
    end
  end

  describe '#orbit_page_label' do
    it 'returns Explore by default' do
      allow(helper).to receive(:params).and_return({})

      expect(helper.orbit_page_label).to eq('Explore')
    end

    it 'returns Schema for the schema route' do
      allow(helper).to receive(:params).and_return({ vueroute: 'schema' })

      expect(helper.orbit_page_label).to eq('Schema')
    end

    it 'returns Schema for nested schema routes' do
      allow(helper).to receive(:params).and_return({ vueroute: 'schema/edges' })

      expect(helper.orbit_page_label).to eq('Schema')
    end

    it 'returns Explore for any other route' do
      allow(helper).to receive(:params).and_return({ vueroute: 'configuration' })

      expect(helper.orbit_page_label).to eq('Explore')
    end
  end
end
