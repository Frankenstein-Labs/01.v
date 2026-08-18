# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersionPolicy, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:sbom_component_version) { create(:sbom_component_version) }

  subject { described_class.new(user, sbom_component_version) }

  describe "reading Sbom::ComponentVersion present in GitLab" do
    it { is_expected.to be_allowed(:read_component_version) }
  end
end
