# frozen_string_literal: true

require "spec_helper"

RSpec.describe Namespaces::Storage::NamespaceLimit::SubgroupPreEnforcementAlertComponent,
  :saas, feature_category: :consumables_cost_management do
  let_it_be_with_refind(:group) { create(:group, :with_root_storage_statistics) }
  let_it_be_with_refind(:subgroup) { create(:group, parent: group) }
  let_it_be_with_refind(:user) { create(:user) }

  subject(:component) { described_class.new(context: subgroup, user: user) }

  before do
    stub_ee_application_setting(should_check_namespace_plan: true, automatic_purchased_storage_allocation: true)
  end

  context 'when subgroup' do
    before do
      group.root_storage_statistics.update!(
        storage_size: 5.gigabytes
      )
      stub_member_access_level(subgroup, guest: user)
      create(:plan_limits, plan: group.root_ancestor.actual_plan, notification_limit: 500)
    end

    it 'includes the correct subgroup info in the alert text' do
      render_inline(component)

      expect(page).to have_text "The #{subgroup.name} group will be affected by this."
    end
  end
end
