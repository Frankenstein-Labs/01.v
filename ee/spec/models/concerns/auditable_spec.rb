# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Auditable, feature_category: :compliance_management do
  shared_examples 'auditable concern' do |audit_details_implemented: false|
    describe '#push_audit_event', :request_store do
      let(:event) { 'Added a new cat to the house' }

      context 'when audit event queue is active' do
        before do
          allow(::Gitlab::Audit::EventQueue).to receive(:active?).and_return(true)
        end

        it 'add message to audit event queue after commit' do
          instance.push_audit_event(event)

          expect(::Gitlab::Audit::EventQueue.current).to be_empty

          instance.save!

          expect(::Gitlab::Audit::EventQueue.current).to eq([event])
        end
      end

      context 'when audit event queue is not active' do
        before do
          allow(::Gitlab::Audit::EventQueue).to receive(:active?).and_return(false)
        end

        it 'does not add message to audit event queue' do
          instance.push_audit_event(event)
          instance.save!

          expect(::Gitlab::Audit::EventQueue.current).to eq([])
        end
      end
    end

    describe '#audit_details' do
      if audit_details_implemented
        it 'does not raise an error when already implemented' do
          expect { instance.audit_details }.not_to raise_error
        end
      else
        it 'raises error to prompt for implementation' do
          expect { instance.audit_details }.to raise_error(/does not implement audit_details/)
        end
      end
    end
  end

  describe 'approval_project_rule' do
    it_behaves_like 'auditable concern' do
      let_it_be_with_reload(:instance) { create(:approval_project_rule) }
    end
  end

  describe 'external_status_check' do
    it_behaves_like 'auditable concern' do
      let_it_be_with_reload(:instance) { create(:external_status_check) }
    end
  end

  describe 'packages_package' do
    let_it_be_with_reload(:instance) { create(:generic_package) }

    it_behaves_like 'auditable concern'

    context 'when calling push_audit_event with after_commit: false', :request_store do
      before do
        allow(::Gitlab::Audit::EventQueue).to receive(:active?).and_return(true)
      end

      it 'does not call run_after_commit' do
        expect(instance).not_to receive(:run_after_commit)

        instance.push_audit_event('event', after_commit: false)
      end
    end
  end

  describe 'security_policy' do
    it_behaves_like 'auditable concern' do
      let_it_be_with_reload(:instance) { create(:security_policy) }
    end
  end

  describe 'merge_request' do
    let_it_be_with_reload(:instance) { create(:merge_request) }

    it_behaves_like 'auditable concern', audit_details_implemented: true
  end
end
