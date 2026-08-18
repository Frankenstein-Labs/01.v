# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::CreateSecurityContextService, feature_category: :static_application_security_testing do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }
  let_it_be(:scan) { create(:security_ascp_scan, project: project) }
  let_it_be(:component) { create(:security_ascp_component, project: project, scan: scan) }

  let(:guidelines) do
    [
      {
        name: 'SQL Injection Prevention',
        operation: 'Database queries',
        legitimate_use: 'Parameterized queries only',
        security_boundary: 'User input in SQL',
        business_context: 'Data integrity risk',
        severity_if_violated: 'high'
      },
      {
        name: 'XSS Prevention',
        operation: 'HTML rendering',
        legitimate_use: 'Escaped output only',
        security_boundary: 'User input in HTML',
        severity_if_violated: 'medium'
      }
    ]
  end

  let(:params) do
    {
      component_id: component.id,
      scan_id: scan.id,
      guidelines: guidelines,
      summary: 'Security analysis summary',
      authentication_model: 'OAuth 2.0',
      authorization_model: 'RBAC',
      data_sensitivity: 'high'
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

      it 'does not create any records' do
        expect { service.execute }
          .to not_change { Security::Ascp::SecurityContext.count }
          .and not_change { Security::Ascp::SecurityGuideline.count }
      end
    end

    context 'when all parameters are valid' do
      it 'creates a security context' do
        expect { service.execute }.to change { Security::Ascp::SecurityContext.count }.by(1)
      end

      it 'creates all guidelines' do
        expect { service.execute }.to change { Security::Ascp::SecurityGuideline.count }.by(2)
      end

      it 'returns a successful response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:security_context]).to be_a(Security::Ascp::SecurityContext)
      end

      it 'associates guidelines with the security context' do
        result = service.execute
        security_context = result.payload[:security_context]

        expect(security_context.guidelines.count).to eq(2)
        expect(security_context.guidelines.map(&:name)).to contain_exactly(
          'SQL Injection Prevention',
          'XSS Prevention'
        )
      end

      it 'sets the correct attributes on security context' do
        result = service.execute
        security_context = result.payload[:security_context]

        expect(security_context.summary).to eq('Security analysis summary')
        expect(security_context.authentication_model).to eq('OAuth 2.0')
        expect(security_context.authorization_model).to eq('RBAC')
        expect(security_context.data_sensitivity).to eq('high')
      end

      it 'uses default severity when not specified' do
        params_with_default = params.merge(
          guidelines: [{ name: 'Test Policy', operation: 'test operation' }]
        )

        result = described_class.new(current_user: user, project: project, params: params_with_default).execute
        guideline = result.payload[:security_context].guidelines.first

        expect(guideline.severity_if_violated).to eq('medium')
      end
    end

    context 'when component is not found in the project' do
      let(:params) { super().merge(component_id: non_existing_record_id) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Component not found in this project')
      end
    end

    context 'when scan is not found in the project' do
      let(:params) { super().merge(scan_id: non_existing_record_id) }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Scan not found in this project')
      end
    end

    context 'when guidelines are empty' do
      let(:guidelines) { [] }

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Guidelines must not be empty')
      end

      it 'does not create any records' do
        expect { service.execute }
          .to not_change { Security::Ascp::SecurityContext.count }
          .and not_change { Security::Ascp::SecurityGuideline.count }
      end
    end

    context 'when guidelines exceed maximum limit' do
      let(:guidelines) do
        (1..101).map { |i| { name: "Guideline #{i}", operation: "Operation #{i}" } }
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Maximum 100 guidelines allowed')
      end
    end

    context 'when guideline has blank name' do
      let(:guidelines) do
        [{ name: '', operation: 'valid operation' }]
      end

      it 'returns an error with guideline index' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Guideline 1: name can't be blank")
      end
    end

    context 'when guideline has blank operation' do
      let(:guidelines) do
        [{ name: 'Valid Policy', operation: '' }]
      end

      it 'returns an error with guideline index' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq("Guideline 1: operation can't be blank")
      end
    end

    context 'when guideline name exceeds maximum length' do
      let(:guidelines) do
        [{ name: 'A' * 256, operation: 'valid operation' }]
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('name is too long')
      end
    end

    context 'when guideline operation exceeds maximum length' do
      let(:guidelines) do
        [{ name: 'Valid Policy', operation: 'A' * 1025 }]
      end

      it 'returns an error' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include('operation is too long')
      end
    end

    context 'when security context creation raises RecordInvalid' do
      before do
        create(:security_ascp_security_context, project: project, component: component, scan: scan)
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to be_present
      end
    end
  end
end
