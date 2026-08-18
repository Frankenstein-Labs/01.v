# frozen_string_literal: true

RSpec.shared_examples 'quick actions that change work item type ee' do
  include_context 'with work item change type context'

  describe 'type command' do
    let(:new_type) { 'issue' }
    let(:command) { %(/type "#{new_type}") }

    context 'with epic' do
      let_it_be(:work_item, freeze: false) { create(:work_item, :epic, namespace: group, title: 'Work item Epic') }
      let(:with_access) { true }

      it 'does not change work item type' do
        expect { service.execute(command, work_item) }
          .not_to change { work_item.work_item_type.base_type }
      end
    end

    context 'with a custom work item type' do
      # The shared context's `project` is a private user-namespaced project, where
      # the EE Provider does not enable custom types. Use a group-owned project so
      # the configurable types feature flag check passes.
      let_it_be(:custom_group, freeze: false) { create(:group) }
      let_it_be(:custom_project, freeze: false) { create(:project, group: custom_group) }
      let_it_be(:custom_type, freeze: false) do
        create(:work_item_custom_type, :with_organization,
          organization: custom_group.organization, name: 'Bug Report')
      end

      let_it_be_with_reload(:work_item) { create(:work_item, project: custom_project) }
      let(:service) { QuickActions::InterpretService.new(container: custom_project, current_user: current_user) }
      let(:command) { %(/type "#{custom_type.name}") }

      before do
        # current_user is defined via `let` (not `let_it_be`) in the spec, so we cannot
        # add the developer in a before_all block.
        custom_project.add_developer(current_user) # rubocop:disable RSpec/BeforeAllRoleAssignment -- see comment above
      end

      it 'resolves the custom type by exact name and populates the update' do
        _, updates, message = service.execute(command, work_item)

        expect(message).to eq(_('Type changed successfully.'))
        expect(updates[:work_item_type].name).to eq(custom_type.name)
      end

      context 'when the type name is provided in a different case' do
        # The input is titleized before matching, so `"bug report"` normalizes to
        # `Bug Report` and resolves the custom type just like the canonical form.
        let(:command) { '/type "bug report"' }

        it 'resolves the custom type after titleizing the input' do
          _, updates, message = service.execute(command, work_item)

          expect(message).to eq(_('Type changed successfully.'))
          expect(updates[:work_item_type].name).to eq(custom_type.name)
        end
      end
    end
  end

  describe 'promote_to command' do
    let(:new_type) { 'objective' }
    let(:command) { "/promote_to #{new_type}" }

    context 'with key result' do
      let_it_be(:work_item, freeze: false) { create(:work_item, :key_result, project: project) }
      let(:with_access) { true }
      let(:new_type) { 'objective' }
      let(:command) { "/promote_to #{new_type}" }

      it 'populates :work_item_type' do
        _, updates, message = service.execute(command, work_item)

        expect(message).to eq(_('Promoted successfully.'))
        expect(updates).to eq(
          { work_item_type: build(:work_item_system_defined_type, :objective) }
        )
      end

      context 'when new type is not supported' do
        let(:new_type) { 'task' }

        it_behaves_like 'quick command error', 'Provided type is not supported', 'promote'
      end

      context 'when user has insufficient permissions to create new type' do
        let(:with_access) { false }

        it_behaves_like 'quick command error', 'You have insufficient permissions', 'promote'
      end
    end
  end
end
