# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::SshCertificates::DestroyService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:ssh_certificate, freeze: false) { create(:group_ssh_certificate) }
  let_it_be_with_reload(:group) { create(:group, ssh_certificates: [ssh_certificate]) }
  let_it_be(:current_user) { create(:user) }
  let(:ssh_certificate_params) { { ssh_certificates_id: ssh_certificate.id } }
  let(:service) { described_class.new(group, ssh_certificate_params, current_user) }

  context 'when group and params are provided' do
    it 'succeeds' do
      expect(group.ssh_certificates.size).to eq(1)
      service.execute
      expect(group.ssh_certificates.size).to eq(0)
    end
  end

  context 'when ssh_certificate_id is not provided' do
    let(:ssh_certificate_params) { {} }

    it 'fails with validation error' do
      response = service.execute
      expect(response.success?).to eq(false)
      expect(response.errors.first).to eq("SSH Certificate not found")
    end
  end

  context "when ssh_certificate doesn't exist" do
    let(:ssh_certificate_params) { { ssh_certificates_id: 9999 } }

    it 'fails with validation error' do
      response = service.execute
      expect(response.success?).to eq(false)
      expect(response.errors.first).to eq("SSH Certificate not found")
    end
  end

  context 'when deleting an SSH certificate' do
    it_behaves_like 'audit event logging' do
      let(:operation) { service.execute }
      let(:attributes) do
        {
          author_id: current_user.id,
          entity_id: group.id,
          entity_type: 'Group',
          details: {
            author_class: 'User',
            author_name: current_user.name,
            event_name: "delete_ssh_certificate",
            custom_message: "Deleted SSH certificate with id #{ssh_certificate.id} and title #{ssh_certificate.title}",
            target_details: ssh_certificate.title,
            target_id: ssh_certificate.id,
            target_type: 'Groups::SshCertificate'
          }
        }
      end

      def fail_condition!
        allow(group.ssh_certificates).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
