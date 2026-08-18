# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::ExternalStatusCheck, feature_category: :source_code_management do
  subject { described_class.new(external_status_check).as_json }

  let(:external_status_check) { build(:external_status_check) }

  it 'exposes correct attributes' do
    is_expected.to include(:id, :name, :project_id, :hmac, :protected_branches, :external_url)
  end
end
