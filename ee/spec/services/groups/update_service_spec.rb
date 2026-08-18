# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::UpdateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- specs mutate instance AI settings stored on the default organization

  let!(:user) { create(:user) }
  let!(:group) { create(:group, :public).reload } # reload clears previous_changes on the group settings from the create

  context 'audit events' do
    let(:audit_event_params) do
      {
        author_id: user.id,
        entity_id: group.id,
        entity_type: 'Group',
        details: {
          author_name: user.name,
          author_class: user.class.name,
          target_id: group.id,
          target_type: 'Group',
          target_details: group.full_path
        }
      }
    end

    before do
      group.add_owner(user)
    end

    describe '#visibility' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          allow(group).to receive(:save).and_return(false)
        end

        let(:operation_params) { { visibility_level: Gitlab::VisibilityLevel::PRIVATE } }

        let(:attributes) do
          audit_event_params.tap do |param|
            param[:details].merge!(
              change: 'visibility',
              from: 'Public',
              to: 'Private',
              custom_message: "Changed visibility from Public to Private",
              event_name: 'group_visibility_level_updated'
            )
          end
        end
      end
    end

    describe 'ip restrictions' do
      context 'when IP restrictions were changed' do
        include_examples 'audit event logging' do
          let(:fail_condition!) do
            allow(group).to receive(:save).and_return(false)
          end

          let(:operation_params) { { ip_restriction_ranges: '192.168.0.0/24,10.0.0.0/8' } }

          let(:attributes) do
            audit_event_params.tap do |param|
              param[:details].merge!(
                event_name: 'ip_restrictions_changed',
                custom_message: "Group IP restrictions updated from '' to '192.168.0.0/24,10.0.0.0/8'"
              )
            end
          end
        end
      end
    end

    describe 'allowed email domain' do
      context 'when allowed email domains were changed' do
        include_examples 'audit event logging' do
          let(:fail_condition!) do
            allow(group).to receive(:save).and_return(false)
          end

          let(:operation_params) { { allowed_email_domains_list: 'abcd.com,test.com' } }

          let(:attributes) do
            audit_event_params.tap do |param|
              param[:details].merge!(
                event_name: 'allowed_email_domain_updated',
                custom_message: "Allowed email domain names updated from '' to 'abcd.com,test.com'"
              )
            end
          end
        end
      end
    end

    def operation(update_params = operation_params)
      update_group(group, user, **update_params)
    end
  end

  context 'sub group' do
    let(:parent_group) { create :group }
    let(:group) { create(:group, parent: parent_group).reload } # reload clears previous_changes on the group settings

    subject { update_group(group, user, { name: 'new_sub_group_name' }) }

    before do
      parent_group.add_owner(user)
    end

    include_examples 'sends streaming audit event'
  end

  describe 'changing file_template_project_id' do
    let(:group) { create(:group) }
    let(:valid_project) { create(:project, namespace: group) }
    let(:user) { create(:user) }

    def update_file_template_project_id(id)
      update_group(group, user, file_template_project_id: id)
    end

    before do
      stub_licensed_features(custom_file_templates_for_namespace: true)
    end

    context 'as a group maintainer' do
      before do
        group.add_maintainer(user)
      end

      it 'does not allow a project to be removed' do
        set_file_template_project_id(group, valid_project.id)

        expect(update_file_template_project_id(nil)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('cannot be changed by you')
      end

      it 'does not allow a project to be set' do
        expect(update_file_template_project_id(valid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('cannot be changed by you')
      end
    end

    context 'as a group owner' do
      before do
        group.add_owner(user)
      end

      it 'allows a project to be removed' do
        set_file_template_project_id(group, valid_project.id)

        expect(update_file_template_project_id(nil)).to be_truthy
        expect(group.reload.file_template_project_id).to be_nil
      end

      it 'allows a valid project to be set' do
        expect(update_file_template_project_id(valid_project.id)).to be_truthy
        expect(group.reload.file_template_project_id).to eq(valid_project.id)
      end

      it 'does not allow a project outwith the group to be set' do
        invalid_project = create(:project)

        expect(update_file_template_project_id(invalid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('is invalid')
      end

      it 'does not allow a non-existent project to be set' do
        invalid_project = create(:project)
        invalid_project.destroy!

        expect(update_file_template_project_id(invalid_project.id)).to be_falsy
        expect(group.errors[:file_template_project_id]).to include('is invalid')
      end

      context 'in a subgroup' do
        let(:parent_group) { create(:group) }
        let(:hidden_project) { create(:project, :private, namespace: parent_group) }
        let(:group) { create(:group, parent: parent_group) }

        before do
          group.update!(parent: parent_group)
        end

        it 'does not allow a project the group owner cannot see to be set' do
          expect(update_file_template_project_id(hidden_project.id)).to be_falsy
          expect(group.reload.file_template_project_id).to be_nil
        end

        it 'allows a project in the subgroup to be set' do
          expect(update_file_template_project_id(valid_project.id)).to be_truthy
          expect(group.reload.file_template_project_id).to eq(valid_project.id)
        end
      end
    end
  end

  context 'repository_size_limit assignment as Bytes' do
    let_it_be(:group, freeze: false) { create(:group, repository_size_limit: 0) }
    let_it_be(:admin_user) { create(:admin) }

    context 'when the user is an admin and admin mode is enabled', :enable_admin_mode do
      context 'when the param is present' do
        let(:opts) { { repository_size_limit: '100' } }

        it 'converts from MiB to Bytes' do
          update_group(group, admin_user, opts)

          expect(group.reload.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:opts) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          update_group(group, admin_user, opts)

          expect(group.reload.repository_size_limit).to be_nil
        end
      end
    end

    context 'when the user is an admin and admin mode is disabled' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not update the limit' do
        update_group(group, admin_user, opts)

        expect(group.reload.repository_size_limit).to eq(0)
      end
    end

    context 'when the user is not an admin' do
      let(:opts) { { repository_size_limit: '100' } }

      it 'does not persist the limit' do
        update_group(group, user, opts)

        expect(group.reload.repository_size_limit).to eq(0)
      end
    end
  end

  context 'setting ip_restriction' do
    let(:group) { create(:group) }

    subject { update_group(group, user, params) }

    before do
      stub_licensed_features(group_ip_restriction: true)
    end

    context 'when ip_restriction already exists' do
      let!(:ip_restriction) { IpRestriction.create!(group: group, range: '10.0.0.0/8') }

      context 'empty ip restriction param' do
        let(:params) { { ip_restriction_ranges: '' } }

        it 'deletes ip restriction' do
          expect(group.ip_restrictions.first.range).to eql('10.0.0.0/8')

          subject

          expect(group.reload.ip_restrictions.count).to eq(0)
        end
      end
    end
  end

  context 'setting allowed email domain' do
    let(:group) { create(:group, :private) }
    let(:user) { create(:user, email: 'admin@gitlab.com') }

    subject { update_group(group, user, params) }

    before do
      stub_licensed_features(group_allowed_email_domains: true)
    end

    context 'when allowed_email_domain already exists' do
      let!(:allowed_domain) { create(:allowed_email_domain, group: group, domain: 'gitlab.com') }

      context 'allowed_email_domains_list param is not specified' do
        let(:params) { {} }

        it 'does not call EE::AllowedEmailDomains::UpdateService#execute' do
          expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).not_to receive(:execute)

          subject
        end
      end

      context 'allowed_email_domains_list param is blank' do
        let(:params) { { allowed_email_domains_list: '' } }

        context 'as a group owner' do
          before do
            group.add_owner(user)
          end

          it 'calls EE::AllowedEmailDomains::UpdateService#execute' do
            expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).to receive(:execute)

            subject
          end

          it 'update is successful' do
            expect(subject).to eq(true)
          end

          it 'deletes existing allowed_email_domain record' do
            expect { subject }.to change { group.reload.allowed_email_domains.size }.from(1).to(0)
          end
        end

        context 'as a normal user' do
          it 'calls EE::AllowedEmailDomains::UpdateService#execute' do
            expect_any_instance_of(EE::AllowedEmailDomains::UpdateService).to receive(:execute)

            subject
          end

          it 'update is not successful' do
            expect(subject).to eq(false)
          end

          it 'registers an error' do
            subject

            expect(group.errors[:allowed_email_domains]).to include('cannot be changed by you')
          end

          it 'does not delete existing allowed_email_domain record' do
            expect { subject }.not_to change { group.reload.allowed_email_domains.size }
          end
        end
      end
    end
  end

  context 'updating protected params' do
    let(:attrs) { { shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 100 } }

    context 'as an admin' do
      let(:user) { create(:admin) }

      it 'updates the attributes' do
        update_group(group, user, attrs)

        expect(group.shared_runners_minutes_limit).to eq(1000)
        expect(group.extra_shared_runners_minutes_limit).to eq(100)
      end
    end

    context 'as a regular user' do
      it 'ignores the attributes' do
        update_group(group, user, attrs)

        expect(group.shared_runners_minutes_limit).to be_nil
        expect(group.extra_shared_runners_minutes_limit).to be_nil
      end
    end
  end

  context 'when updating enabled_foundational_flows' do
    let_it_be(:fix_pipeline) do
      create(:ai_catalog_foundational_flow, :fix_pipeline, :with_item)
    end

    let_it_be(:code_review) do
      create(:ai_catalog_foundational_flow, :code_review, :with_item)
    end

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:params) do
      {
        enabled_foundational_flows: [fix_pipeline.foundational_flow_reference, code_review.foundational_flow_reference]
      }
    end

    before_all do
      group.add_owner(user)
    end

    it 'schedules cascade worker with user_id', :sidekiq_inline do
      expect(Namespaces::CascadeDuoSettingsWorker).to receive(:perform_async).with(
        group.id,
        hash_including(enabled_foundational_flows: [
          fix_pipeline.foundational_flow_reference, code_review.foundational_flow_reference
        ]),
        user.id
      )

      update_group(group, user, params)
    end

    context 'when flow selection is cleared', :sidekiq_inline do
      let(:params) { { enabled_foundational_flows: [] } }

      before do
        group.namespace_settings.update!(enabled_foundational_flows: [fix_pipeline.foundational_flow_reference])
        group.sync_enabled_foundational_flows!([fix_pipeline.catalog_item.id])
      end

      it 'removes all enabled flows' do
        update_group(group, user, params)

        expect(group.selected_foundational_flow_references).to be_empty
      end
    end

    context 'when verifying no duplicate service calls', :sidekiq_inline do
      it 'calls SeedFoundationalFlowsService exactly once' do
        seed_call_count = 0

        allow(Ai::Catalog::Flows::SeedFoundationalFlowsService).to receive(:new).and_wrap_original do |method, **args|
          seed_call_count += 1
          method.call(**args)
        end

        update_group(group, user, params)

        expect(seed_call_count).to eq(1),
          "Expected SeedFoundationalFlowsService to be called once, but was called #{seed_call_count} times"
      end

      it 'calls sync_enabled_foundational_flows! on parent group exactly once' do
        parent_sync_count = 0

        allow_any_instance_of(Group).to receive(:sync_enabled_foundational_flows!).and_wrap_original do |method, *args|
          parent_sync_count += 1 if method.receiver.id == group.id
          method.call(*args)
        end

        update_group(group, user, params)

        expect(parent_sync_count).to eq(1),
          "Expected parent group sync to be called once, but was called #{parent_sync_count} times"
      end

      it 'calls sync_enabled_foundational_flows! on each descendant group exactly once' do
        subgroup_sync_count = 0

        allow_any_instance_of(Group).to receive(:sync_enabled_foundational_flows!).and_wrap_original do |method, *args|
          subgroup_sync_count += 1 if method.receiver.id == subgroup.id
          method.call(*args)
        end

        update_group(group, user, params)

        expect(subgroup_sync_count).to eq(1),
          "Expected subgroup sync to be called once, but was called #{subgroup_sync_count} times"
      end

      it 'calls SyncFoundationalFlowsService for parent group exactly once' do
        parent_service_count = 0

        allow(Ai::Catalog::Flows::SyncFoundationalFlowsService).to receive(:new)
          .and_wrap_original do |method, container, **args|
            parent_service_count += 1 if container.is_a?(Group) && container.id == group.id
            method.call(container, **args)
          end

        update_group(group, user, params)

        expect(parent_service_count).to eq(1),
          "Expected SyncFoundationalFlowsService for parent to be called once, " \
            "but was called #{parent_service_count} times"
      end
    end

    context 'foundational_agents_statuses audit' do
      include_context 'with mocked Foundational Chat Agents'

      let_it_be(:user) { create(:user) }
      let_it_be_with_reload(:group) { create(:group, :public) }

      before_all do
        group.add_owner(user)
      end

      context 'when foundational_agents_statuses param is absent', :sidekiq_inline do
        it 'does not call FoundationalAgentStatusAuditor' do
          expect(::Ai::FoundationalAgentStatusAuditor).not_to receive(:new)

          update_group(group, user, { name: group.name })
        end
      end

      context 'when foundational_agents_statuses param is present', :sidekiq_inline do
        let(:new_statuses) do
          [
            { reference: foundational_chat_agent_1_ref, enabled: true },
            { reference: foundational_chat_agent_2_ref, enabled: false }
          ]
        end

        it 'calls FoundationalAgentStatusAuditor with before/after statuses' do
          expect(::Ai::FoundationalAgentStatusAuditor).to receive(:new).with(
            hash_including(
              current_user: user,
              scope: group,
              previous_statuses: contain_exactly(
                hash_including(reference: foundational_chat_agent_1_ref, enabled: nil),
                hash_including(reference: foundational_chat_agent_2_ref, enabled: nil)
              ),
              new_statuses: new_statuses,
              default_enabled: true
            )
          ).and_call_original

          update_group(group, user, { foundational_agents_statuses: new_statuses })
        end
      end
    end

    context 'strip_feature_flag_gated_foundational_flows!', :sidekiq_inline do
      let(:fix_pipeline_gated) { false }
      let(:code_review_gated) { false }

      before do
        allow(fix_pipeline).to receive(:blocked_by_feature_flag?).and_return(fix_pipeline_gated)
        allow(code_review).to receive(:blocked_by_feature_flag?).and_return(code_review_gated)
      end

      context 'when all flows pass their feature flag check' do
        it 'passes all refs through to the cascade worker unchanged' do
          update_group(group, user, params)

          expect(group.selected_foundational_flow_references).to match_array([
            fix_pipeline.foundational_flow_reference, code_review.foundational_flow_reference
          ])
        end
      end

      context 'when one flow fails its feature flag check' do
        let(:fix_pipeline_gated) { true }

        it 'strips the gated refeferences' do
          update_group(group, user, params)

          expect(group.selected_foundational_flow_references).to match_array([code_review.foundational_flow_reference])
        end
      end

      context 'when all flows fail their feature flag check' do
        let(:fix_pipeline_gated) { true }
        let(:code_review_gated) { true }

        it 'results in an empty flow selection' do
          update_group(group, user, params)

          expect(group.selected_foundational_flow_references).to be_empty
        end
      end
    end

    context 'capture_previous_foundational_flow_refs' do
      context 'when enabled_foundational_flows param is absent', :sidekiq_inline do
        it 'does not call EnabledFoundationalFlowsAuditor' do
          expect(::Ai::EnabledFoundationalFlowsAuditor).not_to receive(:new)

          update_group(group, user, { name: group.name })
        end
      end

      context 'when enabled_foundational_flows param is present and group has no prior flows', :sidekiq_inline do
        it 'calls EnabledFoundationalFlowsAuditor with empty previous_flow_refs' do
          expect(::Ai::EnabledFoundationalFlowsAuditor).to receive(:new).with(
            hash_including(
              current_user: user,
              group: group,
              previous_flow_refs: [],
              new_flow_refs: [fix_pipeline.foundational_flow_reference, code_review.foundational_flow_reference]
            )
          ).and_call_original

          update_group(group, user, params)
        end
      end

      context 'when enabled_foundational_flows param is present and group already has flows', :sidekiq_inline do
        before do
          group.namespace_settings.update!(enabled_foundational_flows: [fix_pipeline.foundational_flow_reference])
          group.sync_enabled_foundational_flows!([fix_pipeline.catalog_item.id])
        end

        it 'calls EnabledFoundationalFlowsAuditor with previous refs captured before the update' do
          expect(::Ai::EnabledFoundationalFlowsAuditor).to receive(:new).with(
            hash_including(
              current_user: user,
              group: group,
              previous_flow_refs: [fix_pipeline.foundational_flow_reference],
              new_flow_refs: [fix_pipeline.foundational_flow_reference, code_review.foundational_flow_reference]
            )
          ).and_call_original

          update_group(group, user, params)
        end
      end
    end
  end

  context 'updating insight_attributes.project_id param' do
    let(:attrs) { { insight_attributes: { project_id: private_project.id } } }

    shared_examples 'successful update of the Insights project' do
      it 'updates the Insights project' do
        update_group(group, user, attrs)

        expect(group.insight.project).to eq(private_project)
      end
    end

    shared_examples 'ignorance of the Insights project ID' do
      it 'ignores the Insights project ID' do
        update_group(group, user, attrs)

        expect(group.insight).to be_nil
      end
    end

    context 'when project is not in the group' do
      let(:private_project) { create(:project, :private) }

      context 'when user can read the project' do
        before do
          private_project.add_maintainer(user)
        end

        it_behaves_like 'ignorance of the Insights project ID'
      end

      context 'when user cannot read the project' do
        it_behaves_like 'ignorance of the Insights project ID'
      end
    end

    context 'when project is in the group' do
      let(:private_project) { create(:project, :private, group: group) }

      context 'when user can read the project' do
        before do
          private_project.add_maintainer(user)
        end

        it_behaves_like 'successful update of the Insights project'
      end

      context 'when user cannot read the project' do
        it_behaves_like 'ignorance of the Insights project ID'
      end
    end
  end

  context 'updating analytics_dashboards_pointer_attributes.target_project_id param' do
    let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: private_project.id } } }
    let(:private_project) do
      create(:project, :private, group: group).tap do |project|
        project.add_maintainer(user)
      end
    end

    it 'updates the Analytics Dashboards pointer project' do
      update_group(group, user, attrs)

      expect(group.analytics_dashboards_pointer.target_project).to eq(private_project)
    end

    context 'when passing a bogus target project' do
      let(:attrs) { { analytics_dashboards_pointer_attributes: { target_project_id: create(:project).id } } }

      it 'fails' do
        success = update_group(group, user, attrs)

        expect(success).to eq(false)
        expect(group).to be_invalid
      end
    end

    context 'when pointer project is empty' do
      let(:existing_pointer) do
        create(:analytics_dashboards_pointer, namespace: group, target_project: private_project)
      end

      let(:attrs) { { analytics_dashboards_pointer_attributes: { id: existing_pointer.id, target_project_id: '' } } }

      it 'removes pointer project' do
        update_group(group, user, attrs)

        expect(group.reload.analytics_dashboards_pointer).to eq(nil)
      end
    end
  end

  context 'updating `max_personal_access_token_lifetime` param' do
    subject { update_group(group, user, attrs) }

    let_it_be_with_reload(:group) do
      create(:group_with_managed_accounts, :public, max_personal_access_token_lifetime: 1)
    end

    let(:limit) { 10 }
    let(:attrs) { { max_personal_access_token_lifetime: limit } }

    shared_examples_for 'it does not call the update lifetime service' do
      it "doesn't call the update lifetime service" do
        expect(::PersonalAccessTokens::Groups::UpdateLifetimeService).not_to receive(:new)

        subject
      end
    end

    it 'updates the attribute' do
      expect { subject }.to change { group.reload.max_personal_access_token_lifetime }.from(1).to(10)
    end

    context 'when the group does not enforce managed accounts' do
      it_behaves_like 'it does not call the update lifetime service'
    end

    context 'when the group enforces managed accounts' do
      before do
        allow(group).to receive(:enforced_group_managed_accounts?).and_return(true)
      end

      context 'without `personal_access_token_expiration_policy` licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: false)
        end

        it_behaves_like 'it does not call the update lifetime service'
      end

      context 'with personal_access_token_expiration_policy licensed' do
        before do
          stub_licensed_features(personal_access_token_expiration_policy: true)
        end

        context 'when `max_personal_access_token_lifetime` is updated to null value' do
          let(:limit) { nil }

          it_behaves_like 'it does not call the update lifetime service'
        end

        context 'when `max_personal_access_token_lifetime` is updated to a non-null value' do
          it 'executes the update lifetime service' do
            expect_next_instance_of(::PersonalAccessTokens::Groups::UpdateLifetimeService, group) do |service|
              expect(service).to receive(:execute)
            end

            subject
          end
        end
      end
    end
  end

  context 'updating user cap params' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_refind(:group) do
      create(:group, :public,
        namespace_settings: create(:namespace_settings, seat_control: :user_cap, new_user_signups_cap: 1))
    end

    let_it_be(:member) { create(:group_member, :awaiting, :maintainer, source: group) }

    before_all do
      group.add_owner(user)
    end

    subject(:update_cap) { update_group(group, user, attrs) }

    context 'when disabling the setting' do
      let(:attrs) { { seat_control: :off, new_user_signups_cap: nil } }

      it 'auto approves pending members' do
        update_cap

        expect(member.reload).to be_active
      end
    end

    context 'when disabling the setting and leaving the new_user_signups_cap value' do
      let(:attrs) { { seat_control: :off } }

      it 'auto approves pending members' do
        update_cap

        expect(member.reload).to be_active
      end
    end

    context 'when not disabling the setting' do
      let(:attrs) { { new_user_signups_cap: 25 } }

      it 'does not auto approve pending members' do
        update_cap

        expect(member.reload).to be_awaiting
      end
    end

    context 'when switching to block seat overages', :sidekiq_inline do
      let(:attrs) { { seat_control: :block_overages, new_user_signups_cap: nil } }

      it 'removes all pending members' do
        update_cap

        expect(group.members.map(&:user_id)).to eq([user.id])
      end
    end
  end

  shared_examples 'when updating duo settings' do |setting_key, setting_val|
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let(:params) { { setting_key => setting_val } }

    context 'as a normal user' do
      before_all do
        group.add_maintainer(user)
      end

      it 'does not change settings' do
        expect { update_group(group, user, params) }
          .not_to(change { group.namespace_settings.public_send(setting_key) })
      end
    end

    context 'as a group owner' do
      before_all do
        group.add_owner(user)
      end

      before do
        initial_value = !setting_val
        group.namespace_settings.update!(setting_key => initial_value)
      end

      it 'changes settings' do
        expect { update_group(group, user, params) }
          .to(change { group.namespace_settings.public_send(setting_key) }.to(setting_val))
      end

      context 'group has subgroups' do
        let(:subgroup) { create(:group, parent: group) }

        it 'runs worker that sets subgroup duo_features_enabled to match group', :sidekiq_inline do
          subgroup.namespace_settings.update!(setting_key => setting_val)

          update_group(group, user, params)

          expect(subgroup.reload.namespace_settings.reload.send(setting_key)).to eq(setting_val)
        end
      end
    end
  end

  context 'when updating duo_features_enabled' do
    it_behaves_like 'when updating duo settings', :duo_features_enabled, false
  end

  context 'when updating duo_remote_flows_enabled' do
    it_behaves_like 'when updating duo settings', :duo_remote_flows_enabled, false
  end

  context 'when updating ai_audit_events_storage_enabled' do
    it_behaves_like 'when updating duo settings', :ai_audit_events_storage_enabled, true
  end

  context 'when updating duo_foundational_flows_enabled' do
    it_behaves_like 'when updating duo settings', :duo_foundational_flows_enabled, false
  end

  context 'when updating lock_duo_features_enabled' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }

    let(:params) { { lock_duo_features_enabled: true } }

    context 'as a normal user' do
      before_all do
        group.add_maintainer(user)
      end

      it 'does not change settings' do
        expect { update_group(group, user, params) }
         .not_to(change { group.namespace_settings.lock_duo_features_enabled })
      end
    end

    context 'as a group owner' do
      before_all do
        group.add_owner(user)
      end

      it 'changes the group settings' do
        expect { update_group(group, user, params) }
          .to(change { group.namespace_settings.lock_duo_features_enabled }.to(true))
      end
    end
  end

  context 'when duo_availability is set to always_on' do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be_with_reload(:group) { create(:group, :public) }
    let_it_be_with_reload(:subgroup) { create(:group, parent: group) }

    before_all do
      group.add_owner(user)
    end

    before do
      group.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: false)
    end

    it 'enqueues CascadeDuoSettingsWorker with duo_features_enabled: true' do
      expect(Namespaces::CascadeDuoSettingsWorker).to receive(:perform_async).with(
        group.id,
        hash_including(duo_features_enabled: true, lock_duo_features_enabled: true),
        user.id
      )

      update_group(group, user, { duo_availability: 'always_on' })
    end

    it 'sets duo_features_enabled to true on the group namespace settings' do
      update_group(group, user, { duo_availability: 'always_on' })

      expect(group.namespace_settings.reload.duo_features_enabled).to be(true)
    end

    it 'sets lock_duo_features_enabled to true on the group namespace settings' do
      update_group(group, user, { duo_availability: 'always_on' })

      expect(group.namespace_settings.reload.lock_duo_features_enabled).to be(true)
    end

    it 'propagates duo_features_enabled: true to subgroups', :sidekiq_inline do
      subgroup.namespace_settings.update!(duo_features_enabled: false)

      update_group(group, user, { duo_availability: 'always_on' })

      expect(subgroup.namespace_settings.reload.duo_features_enabled).to be(true)
    end
  end

  context 'when the group Duo availability is admin-locked' do
    # A fresh group per example keeps the accumulated group.errors (added when a
    # locked change is rejected) from leaking between examples.
    let(:user) { create(:user) }
    let(:group) { create(:group, :public) }

    before do
      group.add_owner(user)
      group.namespace_settings.update!(
        duo_features_enabled: false,
        lock_duo_features_enabled: true,
        admin_locked_duo_features_enabled: true
      )
    end

    it 'does not let an owner change duo_features_enabled' do
      expect { update_group(group, user, { duo_features_enabled: true }) }
        .not_to change { group.namespace_settings.reload.duo_features_enabled }.from(false)
    end

    it 'does not let an owner change lock_duo_features_enabled' do
      expect { update_group(group, user, { lock_duo_features_enabled: false }) }
        .not_to change { group.namespace_settings.reload.lock_duo_features_enabled }.from(true)
    end

    it 'does not let an owner change duo_availability' do
      expect { update_group(group, user, { duo_availability: 'default_on' }) }
        .not_to change { group.namespace_settings.reload.duo_availability }.from(:never_on)
    end

    it 'fails the update and surfaces a validation error on the group' do
      expect(update_group(group, user, { duo_availability: 'default_on' })).to be(false)

      expect(group.errors[:duo_availability])
        .to include('is locked by an instance administrator and can only be changed by an instance administrator.')
    end

    it 'does not apply unrelated settings changes when a locked value is genuinely changed' do
      expect(update_group(group, user, { duo_availability: 'default_on', description: 'Updated description' }))
        .to be(false)

      expect(group.reload.description).not_to eq('Updated description')
      expect(group.namespace_settings.duo_availability).to eq(:never_on)
    end

    it 'ignores an unchanged duo_availability and still applies unrelated changes' do
      expect(update_group(group, user, { duo_availability: 'never_on', description: 'Updated description' }))
        .to be_truthy

      expect(group.reload.description).to eq('Updated description')
      expect(group.namespace_settings.duo_availability).to eq(:never_on)
      expect(group.errors[:duo_availability]).to be_empty
    end

    it 'ignores a nil locked param instead of treating it as a change' do
      expect(update_group(group, user, { duo_features_enabled: nil, description: 'Updated description' }))
        .to be_truthy

      expect(group.reload.description).to eq('Updated description')
      expect(group.namespace_settings.duo_features_enabled).to be(false)
      expect(group.errors[:duo_features_enabled]).to be_empty
    end

    context 'when the group is not admin-locked' do
      before do
        group.namespace_settings.update!(admin_locked_duo_features_enabled: false)
      end

      it 'lets an owner change duo_availability' do
        expect { update_group(group, user, { duo_availability: 'default_on' }) }
          .to change { group.namespace_settings.reload.duo_availability }.from(:never_on).to(:default_on)
      end
    end

    context 'when an instance admin uses the dedicated override service', :enable_admin_mode do
      let_it_be(:admin) { create(:admin) }

      before do
        stub_licensed_features(ai_features: true)
      end

      it 'can still change the admin-locked Duo availability' do
        response = ::Ai::DuoSettings::SetNamespaceOverrideService.new(
          namespace: group,
          current_user: admin,
          availability: 'always_on'
        ).execute

        expect(response).to be_success
        expect(group.namespace_settings.reload.duo_availability).to eq(:always_on)
      end
    end
  end

  context 'when updating duo_availability' do
    let_it_be(:group, freeze: false) { create(:group, :public) }
    let_it_be(:service_account) { create(:user) }
    let_it_be_with_refind(:integration) { create(:amazon_q_integration, instance: false, group: group) }

    using RSpec::Parameterized::TableSyntax

    where(:duo_availability, :amazon_q_connected, :expected_result) do
      'never_on'    | true  | true
      'never_on'    | false | false
      'always_on'   | true  | false
      'always_on'   | false | false
      'default_off' | true  | false
      'default_off' | false | false
    end

    with_them do
      let(:params) { { duo_availability: duo_availability } }

      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(amazon_q_connected)
        Ai::Setting.for_organization(group.organization).update!(amazon_q_service_account_user_id: service_account.id)
      end

      it 'calls the service when conditions are met' do
        if expected_result
          expect_next_instance_of(::Ai::ServiceAccountMemberRemoveService, user, group, service_account) do |service|
            expect(service).to receive(:execute)
          end
        else
          expect(::Ai::ServiceAccountMemberRemoveService).not_to receive(:new)
        end

        update_group(group, user, params)
      end
    end

    context 'when updating Amazon Q auto_review_enabled' do
      let(:params) { { duo_availability: 'default_on', amazon_q_auto_review_enabled: true } }

      it 'does not change Amazon Q integration' do
        expect(PropagateIntegrationWorker).not_to receive(:perform_async)
        expect { update_group(group, user, params) }.not_to change {
          group.amazon_q_integration.reload.auto_review_enabled
        }
      end

      context 'when Amazon Q is connected' do
        before do
          allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        end

        it 'changes Amazon Q integration values' do
          expect(PropagateIntegrationWorker).to receive(:perform_async).with(integration.id)
          expect { update_group(group, user, params) }.to change {
            group.amazon_q_integration.reload.auto_review_enabled
          }.from(false).to(true)
        end

        context 'when amazon_q_auto_review_enabled is nil' do
          let(:params) { { duo_availability: 'default_on', amazon_q_auto_review_enabled: nil } }

          it 'does not update auto_review_enabled setting' do
            expect { update_group(group, user, params) }.not_to change {
              group.amazon_q_integration.reload.auto_review_enabled
            }
          end
        end

        context 'when duo_availability is always_on' do
          let(:params) { { duo_availability: 'always_on' } }

          before do
            integration.update!(availability: 'default_off')
          end

          it 'maps always_on to default_on and propagates the integration' do
            expect(PropagateIntegrationWorker).to receive(:perform_async).with(integration.id)
            expect { update_group(group, user, params) }.to change {
              group.amazon_q_integration.reload.availability
            }.from('default_off').to('default_on')
          end
        end
      end
    end

    context 'for duo workflow group authorization' do
      before do
        allow(::Ai::DuoWorkflow).to receive(:connected?).and_return(duo_workflow_connected)
        Ai::Setting.for_organization(group.organization)
          .update!(duo_workflow_service_account_user_id: service_account.id)
      end

      where(:duo_availability, :duo_workflow_connected, :expected_result) do
        'never_on'    | true  | true
        'never_on'    | false | false
        'always_on'   | true  | false
        'always_on'   | false | false
        'default_off' | true  | false
        'default_off' | false | false
      end

      with_them do
        let(:params) { { duo_availability: duo_availability } }

        it 'calls the service when conditions are met' do
          if expected_result
            expect_next_instance_of(::Ai::ServiceAccountMemberRemoveService, user, group, service_account) do |service|
              expect(service).to receive(:execute)
            end
          else
            expect(::Ai::ServiceAccountMemberRemoveService).not_to receive(:new)
          end

          update_group(group, user, params)
        end
      end
    end
  end

  context 'when ai settings change', :saas do
    before do
      allow(Gitlab).to receive(:com?).and_return(true)
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_licensed_features(ai_features: true)
      group.add_owner(user)
    end

    context 'when experiment_features_enabled changes' do
      let(:params) { { experiment_features_enabled: true } }

      it 'publishes an event after successful update' do
        expect do
          update_group(group, user, params)
        end.to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
          .with(group_id: group.id)
      end

      context 'when update fails' do
        before do
          allow(group).to receive(:save).and_return(false)
        end

        it 'does not publish an event' do
          expect do
            update_group(group, user, params)
          end.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
        end
      end
    end

    context 'when experiment_features setting does not change' do
      let(:params) { { experiment_features_enabled: false } }

      before do
        group.namespace_settings.update!(experiment_features_enabled: false)
      end

      it 'does not publish an event' do
        expect do
          update_group(group, user, params)
        end.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
      end
    end
  end

  context 'when mcp server settings change', :saas do
    before do
      allow(Gitlab).to receive(:com?).and_return(true)
      stub_ee_application_setting(should_check_namespace_plan: true)
      group.add_owner(user)
    end

    context 'when mcp_server_enabled changes' do
      let(:params) { { mcp_server_enabled: true } }

      it 'publishes an event after successful update' do
        expect do
          update_group(group, user, params)
        end.to publish_event(::Mcp::ServerSettingsChangedEvent)
          .with(group_id: group.id)
      end

      it 'does not publish the AI-related settings event' do
        expect do
          update_group(group, user, params)
        end.not_to publish_event(::NamespaceSettings::AiRelatedSettingsChangedEvent)
      end

      context 'when update fails' do
        before do
          allow(group).to receive(:save).and_return(false)
        end

        it 'does not publish an event' do
          expect do
            update_group(group, user, params)
          end.not_to publish_event(::Mcp::ServerSettingsChangedEvent)
        end
      end
    end

    context 'when mcp_server_enabled does not change' do
      let(:params) { { mcp_server_enabled: false } }

      before do
        group.namespace_settings.update!(mcp_server_enabled: false)
        group.reload
      end

      it 'does not publish an event' do
        expect do
          update_group(group, user, params)
        end.not_to publish_event(::Mcp::ServerSettingsChangedEvent)
      end
    end
  end

  context 'when updating web_based_commit_signing_enabled' do
    let(:service) do
      described_class.new(group, user, web_based_commit_signing_enabled: web_based_commit_signing_enabled)
    end

    let(:repositories_web_based_commit_signing) { true }
    let(:web_based_commit_signing_enabled) { true }

    before do
      stub_saas_features(repositories_web_based_commit_signing: repositories_web_based_commit_signing)
      group.add_owner(user)
    end

    shared_examples_for 'enqueues job' do
      it 'enqueues a job' do
        expect(Namespaces::CascadeWebBasedCommitSigningEnabledWorker).to receive(:perform_async).with(group.id)
        service.execute
      end
    end

    shared_examples_for 'does not enqueue job' do
      it 'does not enqueue a job' do
        expect(Namespaces::CascadeWebBasedCommitSigningEnabledWorker).not_to receive(:perform_async).with(group.id)
        service.execute
      end
    end

    shared_examples_for 'ignoring web_based_commit_signing_enabled' do
      it 'deletes the parameter' do
        expect(::NamespaceSettings::AssignAttributesService).to receive(:new).with(
          user,
          group,
          hash_not_including(:web_based_commit_signing_enabled)
        ).twice.and_call_original

        service.execute
      end

      it_behaves_like 'does not enqueue job'
    end

    context 'when the repositories_web_based_commit_signing feature is not available' do
      let(:repositories_web_based_commit_signing) { false }

      it_behaves_like 'ignoring web_based_commit_signing_enabled'
    end

    context 'when enabling web_based_commit_signing_enabled' do
      it_behaves_like 'enqueues job'

      context 'and already enabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: true)
          group.reload
        end

        it_behaves_like 'does not enqueue job'
      end
    end

    context 'when disabling web_based_commit_signing_enabled' do
      let(:web_based_commit_signing_enabled) { false }

      it_behaves_like 'enqueues job'

      context 'and already disabled' do
        before do
          group.namespace_settings.update!(web_based_commit_signing_enabled: false)
          group.reload
        end

        it_behaves_like 'does not enqueue job'
      end
    end
  end

  context 'when updating dependency_firewall_enabled', :saas_dependency_firewall do
    before do
      stub_licensed_features(dependency_firewall: true)
      group.add_owner(user)
    end

    it 'persists the setting to namespace_settings' do
      described_class.new(group, user, dependency_firewall_enabled: true).execute

      expect(group.namespace_settings.reload.dependency_firewall_enabled).to be(true)
    end
  end

  context 'when updating built_in_project_templates_enabled' do
    let(:execute) do
      described_class.new(group, user, built_in_project_templates_enabled: built_in_project_templates_enabled).execute
    end

    let(:built_in_project_templates_enabled) { false }

    before do
      stub_licensed_features(built_in_project_templates_enabled: true)
      group.add_owner(user)
    end

    shared_examples_for 'enqueues built_in_project_templates_enabled job' do
      it 'enqueues a job' do
        expect(Namespaces::CascadeBuiltInProjectTemplatesEnabledWorker).to receive(:perform_async)
          .with(group.id, built_in_project_templates_enabled)

        execute
      end
    end

    shared_examples_for 'does not enqueue built_in_project_templates_enabled job' do
      it 'does not enqueue a job' do
        expect(Namespaces::CascadeBuiltInProjectTemplatesEnabledWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when disabling built_in_project_templates_enabled' do
      it_behaves_like 'enqueues built_in_project_templates_enabled job'

      context 'and already disabled' do
        before do
          group.namespace_settings.update!(built_in_project_templates_enabled: false)
          group.reload
        end

        it_behaves_like 'does not enqueue built_in_project_templates_enabled job'
      end
    end

    context 'when enabling built_in_project_templates_enabled' do
      let(:built_in_project_templates_enabled) { true }

      before do
        group.namespace_settings.update!(built_in_project_templates_enabled: false)
        group.reload
      end

      it_behaves_like 'enqueues built_in_project_templates_enabled job'

      context 'and already enabled' do
        before do
          group.namespace_settings.update!(built_in_project_templates_enabled: true)
          group.reload
        end

        it_behaves_like 'does not enqueue built_in_project_templates_enabled job'
      end
    end
  end

  context 'remove_dormant_members feature handling' do
    shared_examples 'does not schedule worker' do |worker|
      it "does not schedule #{worker} worker" do
        expect(worker).not_to receive(:perform_with_capacity)

        update_group(group.reload, user, params)
      end
    end

    context 'when remove_dormant_members feature changes' do
      context 'when remove_dormant_members feature is initially disabled and is enabled in the params' do
        let(:params) { { remove_dormant_members: true } }
        let(:worker) { Namespaces::RemoveDormantMembersWorker }

        it 'schedules Namespaces::RemoveDormantMembersWorker workers' do
          expect(worker).to receive(:perform_with_capacity).once

          update_group(group, user, params)
        end
      end

      context 'when remove_dormant_members feature is initially disabled and the update to enable it fails' do
        let(:params) { { remove_dormant_members: true } }

        before do
          allow(group).to receive(:save).and_return(false)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is initially enabled and is disabled in the params' do
        let(:params) { { remove_dormant_members: false } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end
    end

    context 'when remove_dormant_members feature does not change' do
      context 'when remove_dormant_members setting is disabled and a value of false is passed for it in the params' do
        let(:params) { { remove_dormant_members: false } }

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is initially disabled and another group setting is changed' do
        let(:params) { { experiment_features_enabled: true } }

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when remove_dormant_members feature is already enabled and another group setting is changed' do
        let(:params) { { experiment_features_enabled: true } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end

      context 'when the remove_dormant_members feature is already enabled and its param has a value of true' do
        let(:params) { { remove_dormant_members: true } }

        before do
          group.namespace_settings.update!(remove_dormant_members: true)
        end

        it_behaves_like 'does not schedule worker', Namespaces::RemoveDormantMembersWorker
      end
    end
  end

  context 'when updating auto_duo_code_review_enabled' do
    let(:params) { { auto_duo_code_review_enabled: true } }

    context 'when auto_duo_code_review_settings is not available' do
      before do
        allow(group).to receive(:auto_duo_code_review_settings_available?).and_return(false)
      end

      it 'removes the parameter' do
        expect { update_group(group, user, params) }
          .not_to change { group.namespace_settings.reload.auto_duo_code_review_enabled }
      end
    end

    context 'when updating auto_duo_code_review_enabled' do
      let(:params) { { auto_duo_code_review_enabled: true } }

      context 'when auto_duo_code_review_settings is not available' do
        before do
          group.add_owner(user)
          allow(group).to receive(:auto_duo_code_review_settings_available?).and_return(false)
        end

        it 'removes the parameter' do
          expect { update_group(group, user, params) }
            .not_to change { group.namespace_settings.reload.auto_duo_code_review_enabled }
        end
      end

      context 'when auto_duo_code_review_settings is available' do
        before do
          allow_any_instance_of(Group).to receive(:auto_duo_code_review_settings_available?).and_return(true)
        end

        it_behaves_like 'when updating duo settings', :auto_duo_code_review_enabled, true
      end
    end
  end

  context 'when updating duo_namespace_access_rules', :saas do
    let(:through_namespace_a) { create(:group, parent: group) }
    let(:through_namespace_b) { create(:group, parent: group) }

    let(:rules) do
      [
        { through_namespace: { id: through_namespace_a.id }, features: ['duo_classic'] },
        { through_namespace: { id: through_namespace_b.id }, features: ['duo_agent_platform'] }
      ]
    end

    let(:params) { { duo_namespace_access_rules: rules } }

    before do
      group.add_owner(user)
    end

    context 'when rules are valid' do
      it 'creates namespace feature access rules' do
        expect { update_group(group, user, params) }
          .to change { group.ai_feature_rules.count }.from(0).to(2)
      end

      context 'when more than 2 through_namespaces are provided' do
        let(:through_namespace_c) { create(:group, parent: group) }
        let(:through_namespace_d) { create(:group, parent: group) }

        it 'does not cause N+1 queries when adding more namespaces' do
          three_ns_params = {
            duo_namespace_access_rules: [
              { through_namespace: { id: through_namespace_a.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_b.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_c.id }, features: ['duo_classic'] }
            ]
          }

          control = ActiveRecord::QueryRecorder.new { update_group(group, user, three_ns_params) }

          four_ns_params = {
            duo_namespace_access_rules: [
              { through_namespace: { id: through_namespace_a.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_b.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_c.id }, features: ['duo_classic'] },
              { through_namespace: { id: through_namespace_d.id }, features: ['duo_classic'] }
            ]
          }

          expect { update_group(group, user, four_ns_params) }.not_to exceed_query_limit(control)
        end
      end

      it 'deletes existing feature access rules and creates new ones' do
        existing_rule = create(:ai_namespace_feature_access_rules,
          through_namespace: through_namespace_a,
          root_namespace: group
        )

        expect { update_group(group, user, params) }
          .to change { group.ai_feature_rules.count }.from(1).to(2)
        expect { existing_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'audits the update' do
        expect(::Ai::FeatureAccessRuleAuditor).to receive(:new).with(
          current_user: user,
          rules: rules,
          scope: group
        ).and_call_original

        update_group(group, user, params)
      end

      context 'when duo_namespace_access_rules is empty' do
        let(:rules) { [] }

        it 'deletes existing access rules' do
          create(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace_a,
            root_namespace: group
          )

          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(1).to(0)
        end

        it 'audits the update' do
          expect(::Ai::FeatureAccessRuleAuditor).to receive(:new).with(
            current_user: user,
            rules: rules,
            scope: group
          ).and_call_original

          update_group(group, user, params)
        end
      end
    end

    context 'when rules are invalid' do
      let(:rules) do
        [
          through_namespace: { id: through_namespace_a.id }, features: ['invalid_entity']
        ]
      end

      it 'adds errors to the group' do
        result = update_group(group, user, params)

        expect(result).to be false
        expect(group.ai_feature_rules).to be_empty
      end

      it 'does not create an audit event' do
        expect(::Ai::FeatureAccessRuleAuditor).not_to receive(:new)

        update_group(group, user, params)
      end
    end

    context 'when the user lacks admin_namespace permission on a through_namespace' do
      let(:unauthorized_namespace) { create(:group) }
      let(:rules) do
        [{ through_namespace: { id: unauthorized_namespace.id }, features: ['duo_classic'] }]
      end

      it 'raises Gitlab::Access::AccessDeniedError' do
        expect { update_group(group, user, params) }.to raise_error(Gitlab::Access::AccessDeniedError)
      end

      it 'does not create any access rules' do
        expect { update_group(group, user, params) }
          .to raise_error(Gitlab::Access::AccessDeniedError)
          .and not_change { group.ai_feature_rules.count }
      end
    end

    context 'when a through_namespace does not exist' do
      let(:rules) do
        [{ through_namespace: { id: non_existing_record_id }, features: ['duo_classic'] }]
      end

      it 'silently drops the rule and does not create any access rules' do
        expect { update_group(group, user, params) }
          .not_to change { group.ai_feature_rules.count }
      end
    end

    context 'when saving AI feature rules with default rules (through_namespace is null)' do
      context 'with a single default rule' do
        let(:rules) do
          [{ through_namespace: nil, features: ['duo_classic'] }]
        end

        it 'persists the default rule to the database' do
          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(0).to(1)
        end

        it 'creates a rule with correct attributes and persists across reloads' do
          update_group(group, user, params)
          group.reload

          rule = group.ai_feature_rules.first
          expect(rule.through_namespace_id).to be_nil
          expect(rule.accessible_entity).to eq('duo_classic')
        end
      end

      context 'with default and group-based rules' do
        let(:rules) do
          [
            { through_namespace: { id: through_namespace_a.id }, features: ['duo_classic'] },
            { through_namespace: nil, features: ['duo_agent_platform'] }
          ]
        end

        it 'persists both rules with correct attributes' do
          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(0).to(2)

          group.reload
          default_rule = group.ai_feature_rules.find_by(through_namespace_id: nil)
          group_rule = group.ai_feature_rules.find_by(through_namespace_id: through_namespace_a.id)

          expect(default_rule.through_namespace_id).to be_nil
          expect(default_rule.accessible_entity).to eq('duo_agent_platform')
          expect(group_rule.through_namespace_id).to eq(through_namespace_a.id)
          expect(group_rule.accessible_entity).to eq('duo_classic')
        end
      end

      context 'when updating existing rules' do
        before do
          create(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace_a,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          )
        end

        let(:rules) do
          [
            { through_namespace: { id: through_namespace_a.id }, features: ['duo_classic'] },
            { through_namespace: nil, features: ['duo_agent_platform'] }
          ]
        end

        it 'adds default rule while keeping group-based rule' do
          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(1).to(2)

          group.reload
          expect(group.ai_feature_rules.where(through_namespace_id: nil).count).to eq(1)
          expect(group.ai_feature_rules.where(through_namespace_id: through_namespace_a.id).count).to eq(1)
        end
      end

      context 'when removing group-based rule but keeping default' do
        before do
          create(:ai_namespace_feature_access_rules,
            through_namespace: through_namespace_a,
            root_namespace: group,
            accessible_entity: 'duo_classic'
          )
          create(:ai_namespace_feature_access_rules,
            through_namespace: nil,
            root_namespace: group,
            accessible_entity: 'duo_agent_platform'
          )
        end

        let(:rules) do
          [{ through_namespace: nil, features: ['duo_agent_platform'] }]
        end

        it 'removes group-based rule but keeps default rule' do
          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(2).to(1)

          group.reload
          expect(group.ai_feature_rules.first.through_namespace_id).to be_nil
          expect(group.ai_feature_rules.first.accessible_entity).to eq('duo_agent_platform')
        end
      end

      context 'with multiple features for a default rule' do
        let(:rules) do
          [{ through_namespace: nil, features: %w[duo_classic duo_agent_platform] }]
        end

        it 'creates separate rules for each feature and persists them' do
          expect { update_group(group, user, params) }
            .to change { group.ai_feature_rules.count }.from(0).to(2)

          group.reload
          features = group.ai_feature_rules.pluck(:accessible_entity).sort
          expect(features).to eq(%w[duo_agent_platform duo_classic])
          expect(group.ai_feature_rules.where(through_namespace_id: nil).count).to eq(2)
        end
      end
    end
  end

  context 'when updating built_in_project_templates_enabled settings' do
    let(:params) { { built_in_project_templates_enabled: false, lock_built_in_project_templates_enabled: true } }

    before do
      stub_licensed_features(built_in_project_templates_enabled: true)
    end

    it 'updates built_in_project_templates_enabled' do
      expect { update_group(group, user, params) }.to change {
        group.namespace_settings.reload.built_in_project_templates_enabled
      }.from(true).to(false)
    end

    it 'updates lock_built_in_project_templates_enabled' do
      expect { update_group(group, user, params) }.to change {
        group.namespace_settings.reload.lock_built_in_project_templates_enabled
      }.from(false).to(true)
    end

    context 'when the feature is unlicensed' do
      before do
        stub_licensed_features(built_in_project_templates_enabled: false)
      end

      it 'does not update built_in_project_templates_enabled' do
        expect { update_group(group, user, params) }.not_to change {
          group.namespace_settings.reload.built_in_project_templates_enabled
        }.from(true)
      end

      it 'does not update lock_built_in_project_templates_enabled' do
        expect { update_group(group, user, params) }.not_to change {
          group.namespace_settings.reload.lock_built_in_project_templates_enabled
        }.from(false)
      end
    end
  end

  context 'when updating duo_template_project_id' do
    let_it_be(:user) { create(:user) }
    let_it_be(:root_group) { create(:group, :public) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:project_in_group) { create(:project, group: root_group) }
    let_it_be(:other_group) { create(:group, :public) }
    let_it_be(:project_in_other_group) { create(:project, :public, group: other_group) }

    before_all do
      root_group.add_owner(user)
      other_group.add_owner(user)
      subgroup.add_owner(user)
    end

    before do
      root_group.errors.clear
    end

    context 'when group is not root' do
      it 'does not update the namespace template setting' do
        expect do
          update_group(subgroup, user, { duo_template_project_id: project_in_group.id })
        end.not_to change {
          Namespaces::TemplateSetting.find_by(namespace_id: subgroup.id)&.duo_template_project_id
        }
      end

      context 'when duo_template_project_id is nil' do
        it 'does not raise an error assigning unknown attribute to group' do
          expect do
            update_group(subgroup, user, { duo_template_project_id: nil })
          end.not_to raise_error
        end
      end
    end

    context 'when setting a Duo template project' do
      it 'sets duo_template_project_id on the namespace_template_setting' do
        expect do
          update_group(root_group, user, { duo_template_project_id: project_in_group.id })
        end.to change {
          root_group.reload.namespace_template_setting&.duo_template_project_id
        }.from(nil).to(project_in_group.id)
      end
    end

    context 'when resetting the Duo template project' do
      it 'clears duo_template_project_id' do
        root_group.create_namespace_template_setting!(duo_template_project_id: project_in_group.id)

        expect do
          update_group(root_group, user, { duo_template_project_id: nil })
        end.to change {
          root_group.reload.namespace_template_setting.duo_template_project_id
        }.from(project_in_group.id).to(nil)
      end
    end

    context 'when the project is not accessible to the user' do
      let_it_be(:private_project) { create(:project, :private) }

      it 'adds an error and does not save' do
        result = update_group(root_group, user, { duo_template_project_id: private_project.id })

        expect(result).to be_falsey
        expect(root_group.errors[:namespace_template_setting]).to include(
          a_string_matching(/Duo template project is invalid or not accessible/)
        )
      end
    end

    context 'when the project belongs to a different root namespace' do
      it 'adds an error and does not save' do
        result = update_group(root_group, user, { duo_template_project_id: project_in_other_group.id })

        expect(result).to be_falsey
        expect(root_group.errors[:namespace_template_setting]).to include(
          a_string_matching(/Duo template project does not belong to this group/)
        )
      end
    end

    context 'when duo_template_project_id is not in params' do
      it 'does not touch the namespace template setting' do
        expect do
          update_group(root_group, user, { duo_availability: 'default_on' })
        end.not_to change {
          root_group.reload.namespace_template_setting&.duo_template_project_id
        }
      end
    end

    context 'when the user does not have admin_group permission' do
      let_it_be(:maintainer) { create(:user) }

      before_all do
        root_group.add_maintainer(maintainer)
      end

      it 'silently ignores duo_template_project_id and does not update the setting' do
        expect do
          update_group(root_group, maintainer, { duo_template_project_id: project_in_group.id })
        end.not_to change {
          root_group.reload.namespace_template_setting&.duo_template_project_id
        }
      end
    end

    context 'when the value is unchanged' do
      before do
        root_group.create_namespace_template_setting!(duo_template_project_id: project_in_group.id)
      end

      it 'does not call check_duo_template_project_id_change! and does not add errors' do
        expect_any_instance_of(described_class).not_to receive(:check_duo_template_project_id_change!)

        result = update_group(root_group, user, { duo_template_project_id: project_in_group.id })

        expect(result).to be_truthy
        expect(root_group.errors[:namespace_template_setting]).to be_empty
      end
    end
  end

  describe '#handle_code_review_flow_consent_update', feature_category: :duo_code_review do
    using RSpec::Parameterized::TableSyntax

    let(:root_group) { create(:group) }
    let(:user) { create(:user, owner_of: root_group) }

    subject(:execute) { update_group(root_group, user, params) }

    where(
      :has_duo_enterprise,
      :create_consent,
      :foundational_flows_in_params,
      :code_review_in_flows,
      :expected_action
    ) do
      # All give conditions satisfied
      true  | true  | true  | true  | :give
      # Consent param present but code review being disabled -> revoke takes effect
      true  | true  | true  | false | :revoke
      # Consent param present but foundational_flows not in params -> do nothing
      true  | true  | false | false | :nothing
      # No consent param, code review still in flows -> do nothing
      true  | false | true  | true  | :nothing
      # No consent param, code review being disabled -> revoke (just in case)
      true  | false | true  | false | :revoke
      # No consent param, no flows update -> do nothing
      true  | false | false | false | :nothing
      # No add-on, all other give conditions met -> revoke (no add-on always revokes)
      false | true  | true  | true  | :revoke
      # No add-on, no flows update -> nothing (early exit: not updating foundational flows)
      false | false | false | false | :nothing
    end

    with_them do
      let(:params) do
        {
          name: root_group.name
        }.tap do |p|
          p[:create_code_review_flow_consent] = true if create_consent

          if foundational_flows_in_params
            p[:enabled_foundational_flows] = code_review_in_flows ? ['code_review/v1'] : ['bug_triage/v1']
          end
        end
      end

      before do
        allow(root_group).to receive(:has_active_add_on_purchase?)
          .with([:duo_enterprise])
          .and_return(has_duo_enterprise)
      end

      case params[:expected_action]
      when :give
        it 'gives the consent if necessary' do
          execute
          expect(root_group.consented_to?(:code_review_flow_dap_routing)).to be(true)
        end
      when :revoke
        it 'revokes the consent if necessary' do
          execute
          expect(root_group.consented_to?(:code_review_flow_dap_routing)).to be(false)
        end
      when :nothing
        it 'does not change consents' do
          expect { execute }.not_to change { root_group.consented_to?(:code_review_flow_dap_routing) }
        end
      end
    end
  end

  context 'when updating #require_sha_for_merge with a custom role' do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:member_role) { create(:member_role, :guest, :manage_merge_request_settings, namespace: group) }

    before do
      stub_licensed_features(custom_roles: true)
      create(:group_member, :guest, user: user, source: group, member_role: member_role)
    end

    it 'allows updating require_sha_for_merge' do
      expect { update_group(group, user, require_sha_for_merge: true) }
        .to change { group.reload.require_sha_for_merge }.to(true)
    end

    it 'allows updating lock_require_sha_for_merge' do
      expect { update_group(group, user, lock_require_sha_for_merge: true) }
        .to change { group.reload.lock_require_sha_for_merge }.to(true)
    end
  end

  context 'when disallowing more restrictive 2FA for subgroups' do
    let_it_be(:owner) { create(:user) }
    let_it_be_with_reload(:root_group) { create(:group) }
    let_it_be_with_reload(:minimal_access_user) { create(:user) }

    let_it_be(:subgroup) do
      create(:group, parent: root_group, require_two_factor_authentication: true, two_factor_grace_period: 23)
    end

    before_all do
      root_group.add_owner(owner)
      create(:group_member, :minimal_access, source: root_group, user: minimal_access_user)

      # The subgroup enforcement gives Minimal Access members of the root a 2FA
      # requirement; planted directly since the recalculating callbacks run
      # before the license stub is in place
      minimal_access_user.update!(require_two_factor_authentication_from_group: true, two_factor_grace_period: 23)
    end

    before do
      stub_licensed_features(minimal_access_role: true)
    end

    it 'clears the 2FA requirement for members of the root with the Minimal Access role', :sidekiq_inline do
      expect { update_group(root_group, owner, allow_mfa_for_subgroups: false) }
        .to change { minimal_access_user.reload.require_two_factor_authentication_from_group }
        .from(true).to(false)
    end
  end

  def update_group(group, user, opts)
    Groups::UpdateService.new(group, user, opts).execute
  end
end
