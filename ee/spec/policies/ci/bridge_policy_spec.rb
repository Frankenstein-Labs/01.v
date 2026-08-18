# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::BridgePolicy, feature_category: :continuous_integration do
  let_it_be_with_reload(:downstream_project) { create(:project, :small_repo) }

  it_behaves_like 'a deployable job policy in EE', :ci_bridge do
    before do
      downstream_project.add_maintainer(user)
      allow(job).to receive(:downstream_project).at_least(:once).and_return(downstream_project)
    end
  end
end
