# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::SetNamespaceOverrideService, feature_category: :ai_abstraction_layer do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  let(:current_user) { admin }
  let(:availability) { 'never_on' }
  let(:clear_descendants) { false }

  subject(:service) do
    described_class.new(
      namespace: group,
      current_user: current_user,
      availability: availability,
      clear_descendants: clear_descendants
    )
  end

  before_all do
    group.add_owner(owner)
  end

  before do
    stub_licensed_features(ai_features: true)
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute' do
    context 'when the user is an instance admin', :enable_admin_mode do
      it 'sets the admin-locked override', :aggregate_failures do
        response = service.execute

        expect(response).to be_success

        settings = group.namespace_settings.reset
        expect(settings.admin_locked_duo_features_enabled).to be(true)
      end

      it 'emits an audit event', :aggregate_failures do
        service.execute

        expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
          hash_including(
            name: 'admin_override_set_for_namespace_duo_availability',
            author: admin,
            scope: group,
            target: group,
            message: "Admin set duo_availability override to '#{availability}' for namespace '#{group.full_path}'"
          )
        )
      end

      context 'with availability always_on' do
        let(:availability) { 'always_on' }

        it 'maps to duo_features_enabled true, lock true, and admin-locks', :aggregate_failures do
          service.execute

          settings = group.namespace_settings.reset
          expect(settings.duo_features_enabled).to be(true)
          expect(settings.lock_duo_features_enabled).to be(true)
          expect(settings.admin_locked_duo_features_enabled).to be(true)
        end
      end

      context 'with availability default_on' do
        let(:availability) { 'default_on' }

        it 'maps to duo_features_enabled true, lock false, and does not admin-lock', :aggregate_failures do
          service.execute

          settings = group.namespace_settings.reset
          expect(settings.duo_features_enabled).to be(true)
          expect(settings.lock_duo_features_enabled).to be(false)
          expect(settings.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'with availability default_off' do
        let(:availability) { 'default_off' }

        it 'maps to duo_features_enabled false, lock false, and does not admin-lock', :aggregate_failures do
          service.execute

          settings = group.namespace_settings.reset
          expect(settings.duo_features_enabled).to be(false)
          expect(settings.lock_duo_features_enabled).to be(false)
          expect(settings.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'with availability never_on' do
        let(:availability) { 'never_on' }

        it 'maps to duo_features_enabled false, lock true, and admin-locks', :aggregate_failures do
          service.execute

          settings = group.namespace_settings.reset
          expect(settings.duo_features_enabled).to be(false)
          expect(settings.lock_duo_features_enabled).to be(true)
          expect(settings.admin_locked_duo_features_enabled).to be(true)
        end

        it 'clears experiment_features_enabled as a side-effect' do
          group.namespace_settings.update!(experiment_features_enabled: true)

          service.execute

          expect(group.namespace_settings.reset.experiment_features_enabled).to be(false)
        end
      end

      context 'when transitioning away from a previous never_on override' do
        let(:availability) { 'always_on' }

        before do
          # Mirror the state left behind by a prior never_on override.
          group.namespace_settings.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            experiment_features_enabled: false
          )
        end

        it 'applies the new availability but leaves experiment_features_enabled off', :aggregate_failures do
          response = service.execute

          expect(response).to be_success

          settings = group.namespace_settings.reset
          expect(settings.duo_features_enabled).to be(true)
          expect(settings.lock_duo_features_enabled).to be(true)
          # The never_on side-effect is one-way by design: an Owner must
          # explicitly re-enable experiment features.
          expect(settings.experiment_features_enabled).to be(false)
        end
      end

      context 'with an invalid availability value' do
        let(:availability) { 'sometimes' }

        it 'returns an error and does not change the setting', :aggregate_failures do
          response = service.execute

          expect(response).to be_error
          expect(response.reason).to eq(:invalid_availability)
          expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'with concurrent overrides in the same hierarchy' do
        it 'serializes on a transaction-scoped advisory lock keyed on the tree root' do
          lock_key = "duo_admin_availability_override:#{group.traversal_ids.first}"

          allow(::NamespaceSetting.connection).to receive(:select_value).and_call_original

          service.execute

          expect(::NamespaceSetting.connection)
            .to have_received(:select_value)
            .with(a_string_including("hashtext('#{lock_key}')"))
        end

        context 'when the advisory lock cannot be acquired' do
          before do
            allow(::NamespaceSetting.connection).to receive(:select_value).and_call_original
            allow(::NamespaceSetting.connection)
              .to receive(:select_value)
              .with(a_string_including('pg_try_advisory_xact_lock'))
              .and_return(false)
          end

          it 'returns a conflict error and does not change the setting', :aggregate_failures do
            response = service.execute

            expect(response).to be_error
            expect(response.reason).to eq(:conflict)
            expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
          end
        end
      end

      context 'when a parent group is already admin-locked' do
        let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

        subject(:service) do
          described_class.new(namespace: subgroup, current_user: current_user, availability: availability)
        end

        before do
          group.namespace_settings.update!(admin_locked_duo_features_enabled: true)
        end

        it 'rejects the nested admin override and returns the locked ancestor', :aggregate_failures do
          response = service.execute

          expect(response).to be_error
          expect(response.reason).to eq(:parent_admin_locked)
          expect(response.payload[:namespaces]).to contain_exactly(group)
          expect(subgroup.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
        end
      end

      context 'when a descendant group is already admin-locked' do
        let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

        before do
          subgroup.namespace_settings.update!(
            duo_features_enabled: false,
            lock_duo_features_enabled: true,
            admin_locked_duo_features_enabled: true
          )
        end

        context 'when clear_descendants is false (default)' do
          it 'rejects the override, returns the descendant, and leaves both groups unchanged', :aggregate_failures do
            response = service.execute

            expect(response).to be_error
            expect(response.reason).to eq(:descendant_admin_locked)
            expect(response.payload[:namespaces]).to contain_exactly(subgroup)
            expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
            expect(subgroup.namespace_settings.reset.admin_locked_duo_features_enabled).to be(true)
          end
        end

        context 'with clear_descendants: true' do
          let(:clear_descendants) { true }
          let(:availability) { 'always_on' }

          it 'sets the override and clears the descendant override', :aggregate_failures do
            response = service.execute

            expect(response).to be_success

            settings = group.namespace_settings.reset
            expect(settings.admin_locked_duo_features_enabled).to be(true)
            expect(settings.read_attribute(:lock_duo_features_enabled)).to be(true)

            descendant = subgroup.namespace_settings.reset
            expect(descendant.admin_locked_duo_features_enabled).to be(false)
            expect(descendant.read_attribute(:duo_features_enabled)).to be_nil
            expect(descendant.read_attribute(:lock_duo_features_enabled)).to be(false)
          end

          it 'emits a clear audit event for the descendant', :aggregate_failures do
            service.execute

            expect(Gitlab::Audit::Auditor).to have_received(:audit).with(
              hash_including(
                name: 'admin_override_cleared_for_namespace_duo_availability',
                target: subgroup
              )
            )
          end

          context 'when the parent save fails after descendants were cleared' do
            before do
              parent_setting = group.namespace_settings
              parent_setting.errors.add(:base, 'simulated failure')
              allow(parent_setting).to receive(:save!)
                .and_raise(ActiveRecord::RecordInvalid.new(parent_setting))
            end

            it 'rolls back the clears and does not emit their audit events', :aggregate_failures do
              response = service.execute

              expect(response).to be_error

              descendant = subgroup.namespace_settings.reset
              expect(descendant.admin_locked_duo_features_enabled).to be(true)
              expect(descendant.read_attribute(:duo_features_enabled)).to be(false)
              expect(descendant.read_attribute(:lock_duo_features_enabled)).to be(true)

              expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
                hash_including(name: 'admin_override_cleared_for_namespace_duo_availability')
              )
              expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
                hash_including(name: 'admin_override_set_for_namespace_duo_availability')
              )
            end
          end
        end

        context 'with admin-locked descendants in separate branches' do
          let_it_be_with_reload(:other_subgroup) { create(:group, parent: group) }

          let(:availability) { 'always_on' }

          before do
            other_subgroup.namespace_settings.update!(
              duo_features_enabled: false,
              lock_duo_features_enabled: true,
              admin_locked_duo_features_enabled: true
            )
          end

          it 'rejects and returns every admin-locked descendant', :aggregate_failures do
            response = service.execute

            expect(response).to be_error
            expect(response.reason).to eq(:descendant_admin_locked)
            expect(response.payload[:namespaces]).to contain_exactly(subgroup, other_subgroup)
          end

          context 'with clear_descendants: true' do
            let(:clear_descendants) { true }

            it 'clears every admin-locked descendant', :aggregate_failures do
              response = service.execute

              expect(response).to be_success
              expect(subgroup.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
              expect(other_subgroup.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
            end
          end
        end
      end
    end

    context 'when the user is a group owner' do
      let(:current_user) { owner }

      it 'returns a forbidden error and does not emit an audit event', :aggregate_failures do
        response = service.execute

        expect(response).to be_error
        expect(response.reason).to eq(:forbidden)
        expect(group.namespace_settings.reset.admin_locked_duo_features_enabled).to be(false)
        expect(Gitlab::Audit::Auditor).not_to have_received(:audit).with(
          hash_including(name: 'admin_override_set_for_namespace_duo_availability')
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
          hash_including(name: 'admin_override_set_for_namespace_duo_availability')
        )
      end
    end
  end
end
