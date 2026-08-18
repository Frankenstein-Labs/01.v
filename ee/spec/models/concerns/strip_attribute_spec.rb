# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StripAttribute, feature_category: :shared do
  describe ".strip_attributes!" do
    it { expect(Iteration.strip_attrs).to include(:title) }
    it { expect(GeoNode.strip_attrs).to include(:name) }
    it { expect(SamlGroupLink.strip_attrs).to include(:saml_group_name) }
    it { expect(ComplianceManagement::Framework.strip_attrs).to include(:name, :color) }
  end
end
