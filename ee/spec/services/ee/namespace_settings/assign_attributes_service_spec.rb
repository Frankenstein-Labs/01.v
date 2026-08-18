# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::NamespaceSettings::AssignAttributesService, feature_category: :groups_and_projects do
  let_it_be_with_reload(:nested_group) { create(:group, :nested) }
  let_it_be_with_reload(:group) { nested_group.parent }
  let_it_be_with_reload(:user) { create(:user) }

  subject(:update_settings) { NamespaceSettings::AssignAttributesService.new(user, group, params).execute }

  describe '#execute' do
    context 'when disable_invite_members param present' do
      let(:params) { { disable_invite_members: true } }

      context 'as a non-owner' do
        it 'does not change settings' do
          group.update!(disable_invite_members: true)
          group.save!

          update_settings

          expect(group.disable_invite_members?).to eq(true)
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        it 'changes settings' do
          update_settings

          expect(group.disable_invite_members?).to eq(true)
        end
      end

      context 'as a non-group owner' do
        before_all do
          group.add_maintainer(user)
        end

        it "does not change settings" do
          expect { update_settings }
            .not_to(change { group.disable_invite_members? })
        end
      end

      context 'when not top-level group' do
        let(:group) { nested_group }

        it 'does not change settings' do
          expect { update_settings }
            .not_to(change { group.disable_invite_members? })
        end
      end
    end

    context 'when prevent_forking_outside_group param present' do
      let(:params) { { prevent_forking_outside_group: true } }

      context 'as a normal user' do
        it 'does not change settings' do
          update_settings

          expect { group.save! }
            .not_to(change { group.namespace_settings.prevent_forking_outside_group })
        end

        it 'registers an error' do
          update_settings

          expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        context 'for a group that does not have prevent forking feature' do
          it 'does not change settings' do
            update_settings

            expect { group.save! }
              .not_to(change { group.namespace_settings.prevent_forking_outside_group })
          end

          it 'registers an error' do
            update_settings

            expect(group.errors[:prevent_forking_outside_group]).to include('Prevent forking setting was not saved')
          end
        end

        context 'for a group that has prevent forking feature' do
          before do
            stub_licensed_features(group_forking_protection: true)
          end

          it 'changes settings' do
            update_settings
            group.save!

            expect(group.namespace_settings.reload.prevent_forking_outside_group).to eq(true)
          end
        end
      end
    end

    context 'when service_access_tokens_expiration_enforced param present' do
      let(:params) { { service_access_tokens_expiration_enforced: false } }

      before_all do
        group.add_owner(user)
      end

      it 'changes settings' do
        update_settings

        expect(group.namespace_settings.attributes["service_access_tokens_expiration_enforced"])
          .to eq(false)
      end

      context 'when group is not top level group' do
        let(:group) { nested_group }

        it 'registers an error' do
          update_settings

          expect(group.errors[:service_access_tokens_expiration_enforced])
            .to include('Service access tokens expiration enforced setting was not saved')
        end
      end
    end

    shared_examples 'ignores web-based commit signing parameters' do
      it 'does not change settings' do
        expect { update_settings }
          .not_to(
            change do
              group.namespace_settings.slice(
                :web_based_commit_signing_enabled,
                :lock_web_based_commit_signing_enabled
              )
            end
          )
      end
    end

    shared_examples 'adds web-based commit signing error' do |expected_error|
      it 'adds an error to namespace_settings' do
        update_settings

        expect(group.namespace_settings.errors[:web_based_commit_signing_enabled])
          .to include(expected_error)
      end
    end

    context 'when web_based_commit_signing_enabled param is present' do
      before_all do
        group.add_owner(user)
      end
      let(:params) { { web_based_commit_signing_enabled: true } }

      context 'when set to true' do
        it 'sets web_based_commit_signing_enabled and locks it' do
          update_settings

          expect(group.namespace_settings.web_based_commit_signing_enabled).to eq(true)
          expect(group.namespace_settings.lock_web_based_commit_signing_enabled).to eq(true)
        end
      end

      context 'when set to false' do
        let(:params) { { web_based_commit_signing_enabled: false } }

        it 'sets web_based_commit_signing_enabled and unlocks it' do
          update_settings

          expect(group.namespace_settings.web_based_commit_signing_enabled).to eq(false)
          expect(group.namespace_settings.lock_web_based_commit_signing_enabled).to eq(false)
        end
      end

      context 'when group is not root' do
        let(:group) { nested_group }

        it_behaves_like 'ignores web-based commit signing parameters'

        it_behaves_like 'adds web-based commit signing error', 'only available on top-level groups.'
      end

      context 'when user is not admin' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'ignores web-based commit signing parameters'

        it_behaves_like 'adds web-based commit signing error', 'can only be changed by a group admin.'
      end
    end

    context 'when web_based_commit_signing_enabled param is not present' do
      let(:params) { {} }

      it_behaves_like 'ignores web-based commit signing parameters'
    end

    context 'when policy_store_experiment_enabled param present' do
      let(:params) { { policy_store_experiment_enabled: true } }

      before do
        stub_licensed_features(security_orchestration_policies: true)
        stub_application_setting(policy_store_experiment_enabled: true)
        # group is shared via let_it_be_with_reload and AR#reload does not clear
        # errors, so reset them to isolate each example from prior blocking messages
        group.errors.clear
      end

      context 'as a non-owner' do
        before_all do
          group.add_maintainer(user)
        end

        it 'does not enable the experiment' do
          update_settings

          expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
        end
      end

      context 'as a group owner' do
        before_all do
          group.add_owner(user)
        end

        context 'when the group has no security policies' do
          before do
            allow(group).to receive(:all_security_orchestration_policy_configurations).and_return([])
          end

          it 'enables the experiment' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(true)
            expect(group.errors[:base]).to be_empty
          end
        end

        context 'when the instance setting is disabled' do
          before do
            stub_application_setting(policy_store_experiment_enabled: false)
          end

          it 'blocks enabling with an instance-level error' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
            expect(group.errors[:base].join).to include('not enabled for this instance')
          end
        end

        context 'when the security_policies_v2 feature flag is disabled' do
          before do
            stub_feature_flags(security_policies_v2: false)
          end

          it 'blocks enabling with a feature-unavailable error' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
            expect(group.errors[:base].join).to include('feature is not available')
          end
        end

        context 'when the group has security policies configured' do
          let_it_be(:security_policy) { create(:security_policy) }

          before do
            allow(group).to receive(:all_security_orchestration_policy_configurations)
              .and_return([security_policy.security_orchestration_policy_configuration])
          end

          it 'blocks enabling the experiment' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
            expect(group.errors[:base].join)
              .to include('cannot be enabled while the group has security policies configured')
          end
        end

        context 'when the group only has deleted security policies' do
          let_it_be(:deleted_policy) { create(:security_policy, :deleted) }

          before do
            allow(group).to receive(:all_security_orchestration_policy_configurations)
              .and_return([deleted_policy.security_orchestration_policy_configuration])
          end

          it 'enables the experiment' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(true)
          end
        end

        context 'when disabling the experiment' do
          let(:params) { { policy_store_experiment_enabled: false } }

          before do
            group.namespace_settings.update!(policy_store_experiment_enabled: true)
            stub_application_setting(policy_store_experiment_enabled: false)
          end

          it 'always succeeds without running the coexistence checks' do
            expect(group).not_to receive(:all_security_orchestration_policy_configurations)

            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
          end
        end

        context 'when the group is a subgroup' do
          let(:group) { nested_group }

          it 'blocks enabling with a top-level-group-only error' do
            update_settings

            expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
            expect(group.errors[:base].join)
              .to include('only available on top-level groups.')
          end

          context 'when disabling the experiment' do
            let(:params) { { policy_store_experiment_enabled: false } }

            before do
              group.namespace_settings.update!(policy_store_experiment_enabled: true)
            end

            it 'allows clearing a stale value' do
              update_settings

              expect(group.namespace_settings.policy_store_experiment_enabled).to be(false)
              expect(group.errors[:base]).to be_empty
            end
          end
        end
      end
    end

    shared_examples 'ignores dependency firewall parameters' do
      it 'does not change settings' do
        expect { update_settings }
          .not_to change { group.namespace_settings.dependency_firewall_enabled }
      end
    end

    shared_examples 'adds dependency firewall error' do |expected_error|
      it 'adds an error to namespace_settings' do
        update_settings

        expect(group.namespace_settings.errors[:dependency_firewall_enabled])
          .to include(expected_error)
      end
    end

    context 'when dependency_firewall_enabled param is present' do
      before_all do
        group.add_owner(user)
      end

      let(:params) { { dependency_firewall_enabled: true } }

      context 'when set to true' do
        it 'sets dependency_firewall_enabled' do
          update_settings

          expect(group.namespace_settings.dependency_firewall_enabled).to eq(true)
        end
      end

      context 'when group is not root' do
        let(:group) { nested_group }

        it_behaves_like 'ignores dependency firewall parameters'

        it_behaves_like 'adds dependency firewall error', 'only available on top-level groups.'
      end

      context 'when user is not admin' do
        before_all do
          group.add_guest(user)
        end

        it_behaves_like 'ignores dependency firewall parameters'

        it_behaves_like 'adds dependency firewall error', 'can only be changed by a group admin.'
      end
    end
  end

  describe 'validating settings param for admin' do
    using RSpec::Parameterized::TableSyntax

    where(:setting_key, :setting_changes_from, :setting_changes_to) do
      :duo_features_enabled | false | true
      :lock_duo_features_enabled | false | true
      :duo_remote_flows_enabled | true | false
      :lock_duo_remote_flows_enabled | false | true
      :duo_foundational_flows_enabled | false | true
      :lock_duo_foundational_flows_enabled | false | true
      :ai_audit_events_storage_enabled | false | true
      :lock_ai_audit_events_storage_enabled | false | true
    end

    with_them do
      let(:params) do
        { setting_key => setting_changes_to }
      end

      before do
        group.namespace_settings.update_column(setting_key, setting_changes_from)
      end

      context 'when user is not a group admin' do
        it 'does not change settings' do
          group.add_developer(user)

          expect { update_settings }.not_to change { group.namespace_settings.public_send(setting_key) }
        end

        it 'returns the group admin error' do
          update_settings

          expect(group.namespace_settings.errors.messages[setting_key])
            .to include('can only be changed by a group admin.')
        end
      end

      context 'when user is a group admin' do
        it 'changes settings' do
          group.add_owner(user)

          expect { update_settings }
            .to change { group.namespace_settings.public_send(setting_key) }
                  .from(setting_changes_from).to(setting_changes_to)
        end
      end
    end
  end
end
