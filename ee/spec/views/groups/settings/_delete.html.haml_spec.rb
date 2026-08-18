# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_delete.html.haml', feature_category: :groups_and_projects do
  let(:group) { build_stubbed(:group) }
  let_it_be(:policy_project) { build_stubbed(:project, name: 'Security Policy Project') }
  let_it_be(:linked_project) { build_stubbed(:project, name: 'Linked Project') }
  let(:linked_configurations) do
    [
      build_stubbed(:security_orchestration_policy_configuration,
        security_policy_management_project: policy_project,
        project: linked_project
      )
    ]
  end

  describe 'render' do
    context 'when user can :remove_group' do
      before do
        allow(view).to receive(:can?).with(anything, :remove_group, group).and_return(true)
      end

      it 'enables the Remove group button and does not show an alert for a group' do
        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).not_to match 'data-disabled="true"'
        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end

      it 'shows message for a group with a paid gitlab.com plan', :saas do
        build_stubbed(:gitlab_subscription, :ultimate, namespace: group)

        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_content "This group can't be deleted because it is linked to a subscription."
      end

      it 'shows message for a group with a legacy paid gitlab.com plan', :saas do
        build_stubbed(:gitlab_subscription, :gold, namespace: group)

        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_content "This group can't be deleted because it is linked to a subscription."
      end

      it 'enables the Remove group button and does not show an alert for a subgroup', :saas do
        build_stubbed(:gitlab_subscription, :ultimate, namespace: group)
        subgroup = build_stubbed(:group, parent: group)
        allow(view).to receive(:can?).with(anything, :remove_group, subgroup).and_return(true)

        @group = subgroup
        render 'groups/settings/delete'

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).not_to match 'data-disabled="true"'
        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end

      it 'enables the Remove group button for group with a trial plan', :saas do
        build_stubbed(:gitlab_subscription, :ultimate_trial, :active_trial, namespace: group)

        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_selector '[data-button-testid="remove-group-button"]'
        expect(rendered).not_to match 'data-disabled="true"'
        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end
    end

    context 'when user cannot :remove_group' do
      before do
        allow(view).to receive(:can?).with(anything, :remove_group, group).and_return(false)
      end

      it 'disables the Remove group button for a group' do
        @group = group
        output = view.render('groups/settings/delete')

        expect(output).to be_nil
      end
    end

    context 'when group has linked security policy projects' do
      before do
        allow(view).to receive(:can?).with(anything, :remove_group, group).and_return(true)
        allow(view).to receive(:security_configurations_preventing_group_deletion).and_return({
          limited_configurations: linked_configurations,
          has_more: false
        })
      end

      it 'does not show delete button' do
        @group = group
        render 'groups/settings/delete'

        expect(rendered).not_to have_selector '[data-button-testid="remove-group-button"]'
      end

      it 'shows the message about linked security policy projects' do
        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_content(
          "Group cannot be deleted because it has projects " \
            "that are linked as a security policy project"
        )
      end

      it 'lists the linked projects and their configurations' do
        @group = group
        render 'groups/settings/delete'

        expect(rendered).to have_content policy_project.full_path
        expect(rendered).to have_content linked_project.name
      end

      it 'does not show the subscription alert' do
        @group = group
        render 'groups/settings/delete'

        expect(rendered).not_to have_selector '[data-testid="group-has-linked-subscription-alert"]'
      end
    end
  end
end
