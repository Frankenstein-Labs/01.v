# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Workspaces direct routing", "routing", feature_category: :workspaces do
  describe "#new_remote_development_workspace_path" do
    it "generates correct path for new_remote_development_workspace_path" do
      # noinspection RubyResolve -- Rubymine can't find route helper method
      expect(new_remote_development_workspace_path).to eq("/-/remote_development/workspaces/new")
    end
  end
end
