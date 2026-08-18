# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::CreateComponentService, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }

  let(:params) do
    {
      scan_id: scan.id,
      title: 'Authentication Module',
      sub_directory: 'app/auth',
      description: 'Handles user authentication',
      expected_user_behavior: 'Users log in with email and password'
    }
  end

  subject(:service) { described_class.new(current_user: user, project: project, params: params) }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      let_it_be(:unauthorized_user) { create(:user, guest_of: project) }

      subject(:service) { described_class.new(current_user: unauthorized_user, project: project, params: params) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Insufficient permissions')
      end

      it 'does not create a component' do
        expect { service.execute }.not_to change { Security::Ascp::Component.count }
      end
    end

    context 'when all parameters are valid' do
      it 'creates a component' do
        expect { service.execute }.to change { Security::Ascp::Component.count }.by(1)
      end

      it 'returns a successful response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:component]).to be_a(Security::Ascp::Component)
      end

      it 'sets the correct attributes' do
        result = service.execute
        component = result.payload[:component]

        expect(component).to have_attributes(
          title: 'Authentication Module',
          sub_directory: 'app/auth',
          description: 'Handles user authentication',
          expected_user_behavior: 'Users log in with email and password',
          project: project,
          scan: scan
        )
      end
    end

    context 'when scan belongs to a different project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_scan) { create(:security_ascp_scan, project: other_project) }
      let(:params) { super().merge(scan_id: other_scan.id) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Scan not found in this project')
      end
    end

    context 'when scan is not found in the project' do
      let(:params) { super().merge(scan_id: non_existing_record_id) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Scan not found in this project')
      end

      it 'does not create a component' do
        expect { service.execute }.not_to change { Security::Ascp::Component.count }
      end
    end

    context 'when validation fails' do
      let(:params) { super().merge(title: '') }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to be_present
      end

      it 'does not create a component' do
        expect { service.execute }.not_to change { Security::Ascp::Component.count }
      end
    end
  end
end
