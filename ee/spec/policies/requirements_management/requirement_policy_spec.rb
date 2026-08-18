# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RequirementsManagement::RequirementPolicy do
  let_it_be(:owner) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:planner) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:project) do
    create(:project, :public, namespace: owner.namespace, planners: planner, reporters: reporter, developers: developer,
      maintainers: maintainer, guests: guest)
  end

  let_it_be_with_reload(:resource) { create(:work_item, :requirement, project: project).requirement }

  it_behaves_like 'resource with requirement permissions'
end
