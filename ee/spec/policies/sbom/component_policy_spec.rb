# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentPolicy, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:sbom_component) { create(:sbom_component) }

  subject { described_class.new(user, sbom_component) }

  describe "reading Sbom::Components present in GitLab" do
    it { is_expected.to be_allowed(:read_component) }
  end
end
