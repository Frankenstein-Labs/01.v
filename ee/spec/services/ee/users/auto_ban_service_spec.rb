# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::AutoBanService, feature_category: :instance_resiliency do
  let_it_be_with_reload(:user) { create(:user) }
  let(:reason) { 'reason' }
  let(:service) { described_class.new(user: user, reason: reason) }

  shared_examples 'executing the service' do
    context 'when running in SAAS', :saas do
      it 'executes the Arkose truth data service' do
        expect_next_instance_of(Arkose::TruthDataService, user: user, is_legit: false) do |instance|
          expect(instance).to receive(:execute)
        end

        subject
      end
    end

    context 'when not running in SAAS' do
      it 'does not execute the Arkose truth data service' do
        expect(Arkose::TruthDataService).not_to receive(:new)

        subject
      end
    end
  end

  describe '#execute' do
    subject { service.execute }

    it_behaves_like 'executing the service'
  end

  describe '#execute!' do
    subject { service.execute! }

    it_behaves_like 'executing the service'
  end
end
