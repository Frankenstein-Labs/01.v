# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.shared_examples "workspace_helper_data" do |helper_method:|
  let(:organization) { instance_double("Organizations::Organization", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:mock_helper_class) do
    helper_module = described_class
    Class.new do
      include helper_module
      def new_remote_development_workspace_path
        "/workspaces/new"
      end
    end
  end

  let(:helper) { mock_helper_class.new }

  it 'returns new_workspace_path and organization_id' do
    Current.organization = organization
    expect(helper.public_send(helper_method)).to include(
      new_workspace_path: "/workspaces/new",
      organization_id: 1
    )
  end
end
