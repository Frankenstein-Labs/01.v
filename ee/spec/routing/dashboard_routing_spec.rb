# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dashboard::ProjectsController, "routing", feature_category: :groups_and_projects do
  include RSpec::Rails::RequestExampleGroup

  it "to #removed" do
    expect(get("/dashboard/projects/removed")).to redirect_to('/dashboard/projects/inactive')
  end
end
