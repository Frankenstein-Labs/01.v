# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::ClearNamespaceOverrideService, feature_category: :ai_abstraction_layer do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:current_user) { admin }

  subject(:service) do
    described_class.new(namespace: group, current_user: current_user)
  end

  before_all do
    group.add_owner(owner)
    group.namespace_settings.update!(
      duo_features_enabled: false,
      lock_duo_features_enabled: true,
      admin_locked_duo_features_enabled: true
    )
  end

  before do
    stub_licensed_features(ai_features: true)
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute' do
    context 'when the user is an instance admin', :enable_admin_mode do
      it 'clears the admin-locked override', :aggregate_failures do
        response = service.execute

        expect(response).to be_success

        settings = group.namespace_settings.reset
        expect(settings.admin_locked_duo_features_enabled).to be(false)
        # `duo_features_enabled` is reset to nil at the column level so the
        # cascading reader re-resolves it; the lock is unlocked (NOT NULL).
        expect(settings.read_attribute(:duo_features_enabled)).to be_nil
        expect(settings.read_attribute(:lock_duo_features_enabled)).to be(false)
      end

      it 'emits an audit event capturing the previous duo_availability state', :aggregate_failures do
        previous_availability = group.namespace_settings.duo_availability

        service.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            name: 'admin_override_cleared_for_namespace_duo_availability',
            author: admin,
            scope: group,
            target: group,
            message: "Admin cleared duo_availability override (was '#{previous_availability}') " \
              "for namespace '#{group.full_path}'"
          )
        )
      end
    end

    context 'when executed inside a transaction that rolls back', :enable_admin_mode do
      it 'does not emit an audit event for the reverted clear', :aggregate_failures do
        NamespaceSetting.transaction do
          expect(service.execute).to be_success

          raise ActiveRecord::Rollback
        end

        expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(true)
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(name: 'admin_override_cleared_for_namespace_duo_availability')
        )
      end
    end

    context 'when clearing an override that was set to never_on', :enable_admin_mode do
      before do
        # never_on leaves experiment_features_enabled off as a one-way side-effect.
        group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it 'clears the override but leaves experiment_features_enabled off', :aggregate_failures do
        response = service.execute

        expect(response).to be_success
        # Restoring experiment features is the Owner's responsibility; clearing
        # the admin lock does not re-enable it.
        expect(group.namespace_settings.reset.experiment_features_enabled).to be(false)
      end
    end

    context 'when the user is a group owner' do
      let(:current_user) { owner }

      it 'returns a forbidden error, keeps the override, and does not emit an audit event', :aggregate_failures do
        response = service.execute

        expect(response).to be_error
        expect(response.reason).to eq(:forbidden)
        expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(true)
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(name: 'admin_override_cleared_for_namespace_duo_availability')
        )
      end
    end

    context 'when there is no current user' do
      let(:current_user) { nil }

      it 'returns a forbidden error and does not emit an audit event', :aggregate_failures do
        response = service.execute

        expect(response).to be_error
        expect(response.reason).to eq(:forbidden)
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(name: 'admin_override_cleared_for_namespace_duo_availability')
        )
      end
    end
  end
end
