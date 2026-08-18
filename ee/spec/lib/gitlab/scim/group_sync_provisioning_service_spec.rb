# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Scim::GroupSyncProvisioningService, feature_category: :system_access do
  let(:service) { described_class.new(service_params) }
  let(:scim_group_uid) { SecureRandom.uuid }
  let(:saml_group_name) { 'engineering' }
  let(:service_params) do
    {
      saml_group_name: saml_group_name,
      scim_group_uid: scim_group_uid
    }
  end

  describe '#execute' do
    shared_examples 'success response' do
      it 'contains a success status' do
        expect(service.execute.status).to eq(:success)
      end

      it 'contains a group_link in the response' do
        expect(service.execute.group_link).to be_a(SamlGroupLink)
      end
    end

    context 'when valid params' do
      let!(:saml_group_link) { create(:saml_group_link, saml_group_name: saml_group_name) }

      it_behaves_like 'success response'

      it 'updates the SCIM group ID' do
        expect { service.execute }.to change { saml_group_link.reload.scim_group_uid }.from(nil).to(scim_group_uid)
      end

      context 'with multiple matching group links' do
        let!(:another_group_link) { create(:saml_group_link, saml_group_name: saml_group_name) }

        it 'updates all matching group links' do
          service.execute

          expect(saml_group_link.reload.scim_group_uid).to eq(scim_group_uid)
          expect(another_group_link.reload.scim_group_uid).to eq(scim_group_uid)
        end

        it 'returns the first matching group link in the response' do
          response = service.execute

          expect(response.group_link).to eq(saml_group_link)
        end
      end
    end

    context 'when invalid params' do
      context 'with missing required params' do
        shared_examples 'missing param error' do |param|
          let(:service_params) { base_params.except(param) }
          let(:base_params) do
            {
              saml_group_name: saml_group_name,
              scim_group_uid: scim_group_uid
            }
          end

          it 'fails with error status' do
            expect(service.execute.status).to eq(:error)
          end

          it 'includes the missing param in the error message' do
            expect(service.execute.message).to eq("Missing params: [:#{param}]")
          end
        end

        it_behaves_like 'missing param error', :saml_group_name
        it_behaves_like 'missing param error', :scim_group_uid
      end

      context 'with blank params' do
        shared_examples 'blank param error' do |param|
          let(:service_params) do
            {
              saml_group_name: saml_group_name,
              scim_group_uid: scim_group_uid
            }.merge(param => '')
          end

          it 'fails with error status' do
            expect(service.execute.status).to eq(:error)
          end

          it 'includes the blank param in the error message' do
            expect(service.execute.message).to include("Missing params: [:#{param}]")
          end
        end

        it_behaves_like 'blank param error', :saml_group_name
        it_behaves_like 'blank param error', :scim_group_uid
      end

      context 'when scim_group_uid is not a valid UUID' do
        let(:service_params) do
          {
            saml_group_name: saml_group_name,
            scim_group_uid: 'not-a-valid-uuid'
          }
        end

        it 'fails with error status' do
          expect(service.execute.status).to eq(:error)
        end

        it 'includes appropriate error message' do
          expect(service.execute.message).to eq('Invalid UUID for scim_group_uid')
        end
      end
    end

    context 'when no matching SAML group exists' do
      let(:saml_group_name) { 'nonexistent_group' }

      it 'fails with error status' do
        expect(service.execute.status).to eq(:error)
      end

      it 'includes appropriate error message' do
        expect(service.execute.message).to eq("No matching SAML group found with name: #{saml_group_name}")
      end
    end
  end
end
