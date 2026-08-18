# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VerifyPagesDomainService, feature_category: :pages do
  let(:service) { described_class.new(domain) }

  describe '#execute' do
    subject(:service_response) { service.execute }

    context 'when successful verification' do
      shared_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker' do
        it_behaves_like 'returning a success service response'

        it 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker', :aggregate_failures do
          expect(Groups::EnterpriseUsers::BulkAssociateByDomainWorker).to receive(:perform_async).with(domain.id)

          service_response

          expect(domain).to be_verified
        end
      end

      context 'when domain is disabled(or new)' do
        let(:domain) { create(:pages_domain, :disabled) }

        before do
          stub_resolver(domain.domain => ['something else', domain.verification_code])
        end

        include_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end

      context 'when domain is verified' do
        let(:domain) { create(:pages_domain) }

        before do
          stub_resolver(domain.domain => ['something else', domain.verification_code])
        end

        include_examples 'schedules Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end
    end

    context 'when unsuccessful verification' do
      shared_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker' do
        it_behaves_like 'returning an error service response'
        it { is_expected.to have_attributes message: "Couldn't verify #{domain.domain}" }

        it 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker', :aggregate_failures do
          expect(Groups::EnterpriseUsers::BulkAssociateByDomainWorker).not_to receive(:perform_async)

          service_response

          expect(domain).not_to be_verified
        end
      end

      context 'when domain is disabled(or new)' do
        let(:domain) { create(:pages_domain, :disabled) }

        include_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end

      context 'when domain is verified' do
        let(:domain) { create(:pages_domain) }

        include_examples 'does not schedule Groups::EnterpriseUsers::BulkAssociateByDomainWorker'
      end
    end
  end
end
