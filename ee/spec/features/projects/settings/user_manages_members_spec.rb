# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User manages members", feature_category: :user_profile do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  context "as project maintainer" do
    before do
      project.add_maintainer(user)
    end

    context "when group membership is unlocked" do
      before do
        group.update!(membership_lock: false)

        visit(project_project_members_path(project))
      end

      it { expect(page).to have_selector(".js-invite-members-trigger") }
      it { expect(page).to have_selector(".js-import-project-members-trigger") }
      it { expect(page).to have_no_selector(".js-invite-group-trigger") }
    end

    context "when group membership is locked" do
      before do
        group.update!(membership_lock: true)

        visit(project_project_members_path(project))
      end

      it { expect(page).to have_no_selector(".js-invite-members-trigger") }
      it { expect(page).to have_no_selector(".js-invite-group-trigger") }
    end
  end

  context "as group owner" do
    before do
      group.add_owner(user)
    end

    context "when group membership is unlocked" do
      before do
        group.update!(membership_lock: false)

        visit(project_project_members_path(project))
      end

      it { expect(page).to have_selector(".js-invite-members-trigger") }
      it { expect(page).to have_selector(".js-invite-group-trigger") }
      it { expect(page).to have_selector(".js-import-project-members-trigger") }
    end

    context "when group membership is locked" do
      before do
        group.update!(membership_lock: true)

        visit(project_project_members_path(project))
      end

      it { expect(page).to have_no_selector(".js-invite-members-trigger") }
      it { expect(page).to have_selector(".js-invite-group-trigger") }
    end
  end
end
