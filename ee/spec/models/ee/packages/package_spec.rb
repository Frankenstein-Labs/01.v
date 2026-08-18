# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Package, type: :model, feature_category: :package_registry do
  it { is_expected.to be_a ::Auditable }

  describe '#create_audit_event callback' do
    before do
      allow(::Packages::CreateAuditEventService).to receive(:new).and_call_original
    end

    shared_examples 'creates audit event' do
      it 'calls CreateAuditEventService' do
        subject

        expect(::Packages::CreateAuditEventService).to have_received(:new).with(package)
      end
    end

    shared_examples 'does not create audit event' do
      it 'does not call CreateAuditEventService' do
        subject

        expect(::Packages::CreateAuditEventService).not_to have_received(:new).with(package)
      end
    end

    context 'on create' do
      let(:package) { build(:generic_package) }

      subject { package.save! }

      context 'with default status' do
        it_behaves_like 'creates audit event'
      end

      context 'with non-default status' do
        before do
          package.status = :processing
        end

        it_behaves_like 'does not create audit event'
      end

      context 'with versionless maven package' do
        subject { create(:maven_package, version: nil) }

        it_behaves_like 'does not create audit event'
      end
    end

    context 'on update' do
      using RSpec::Parameterized::TableSyntax

      let_it_be_with_reload(:package) { create(:generic_package) }

      context 'when changing status' do
        subject { package.public_send(:"#{to_status}!") }

        where(:from_status, :to_status, :creates_event) do
          :default     | :pending_destruction | false
          :default     | :hidden              | false
          :hidden      | :default             | false
          :processing  | :default             | true
        end

        before do
          package.public_send(:"#{from_status}!")
        end

        with_them do
          it_behaves_like params[:creates_event] ? 'creates audit event' : 'does not create audit event'
        end
      end

      context 'when updating attributes' do
        subject { package.update!(updates) }

        where(:scenario, :updates, :initial_status, :creates_event) do
          'name only'                      | { name: 'new_name' }                   | :default    | false
          'name and default to hidden'     | { name: 'new_name', status: :hidden }  | :default    | false
          'name and processing to default' | { name: 'new_name', status: :default } | :processing | true
          'name and hidden to default'     | { name: 'new_name', status: :default } | :hidden     | false
        end

        before do
          package.public_send(:"#{initial_status}!")
        end

        with_them do
          it_behaves_like params[:creates_event] ? 'creates audit event' : 'does not create audit event'
        end
      end
    end
  end
end
