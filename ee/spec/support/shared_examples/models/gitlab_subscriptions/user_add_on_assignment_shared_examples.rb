# frozen_string_literal: true

RSpec.shared_examples 'create audits for user add-on assignments' do
  let(:group) { create(:group) }
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:add_on_purchase) do
    create(
      :gitlab_subscription_add_on_purchase,
      namespace: group,
      organization: organization
    )
  end

  it 'creates audits for user add-on assignments' do
    user_add_on_assignment = create(
      :gitlab_subscription_user_add_on_assignment,
      add_on_purchase: add_on_purchase,
      user: user,
      organization_id: organization.id
    )

    expect { entity.destroy! }.to change { GitlabSubscriptions::UserAddOnAssignmentVersion.count }.from(1).to(2)

    version = GitlabSubscriptions::UserAddOnAssignmentVersion.last
    expect(version).to have_attributes(
      add_on_name: add_on_purchase.add_on.name,
      event: 'destroy',
      item_id: user_add_on_assignment.id,
      item_type: 'GitlabSubscriptions::UserAddOnAssignment',
      namespace_path: group.traversal_path(with_organization: false),
      organization_id: organization.id,
      purchase_id: add_on_purchase.id,
      user_id: user.id
    )
    expect(version.object).to include(
      "add_on_purchase_id" => add_on_purchase.id,
      "id" => user_add_on_assignment.id,
      "organization_id" => organization.id,
      "user_id" => user.id
    )
  end
end
