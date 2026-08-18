# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workspaces resources routing", "routing", feature_category: :workspaces do
  describe "/-/remote_development/workspaces" do
    it "routes to workspaces#index" do
      expect(get("/-/remote_development/workspaces")).to route_to(
        controller: "remote_development/workspaces",
        action: "index"
      )
    end

    it "routes to workspaces#index with Vue route parameter" do
      expect(get("/-/remote_development/workspaces/new")).to route_to(
        controller: "remote_development/workspaces",
        action: "index",
        vueroute: "new"
      )
    end

    it "routes to workspaces#index with nested Vue route parameter" do
      expect(get("/-/remote_development/workspaces/123/details")).to route_to(
        controller: "remote_development/workspaces",
        action: "index",
        vueroute: "123/details"
      )
    end
  end
end
