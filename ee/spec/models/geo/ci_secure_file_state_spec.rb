# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CiSecureFileState, :geo, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:ci_secure_file).inverse_of(:ci_secure_file_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:ci_secure_file) }
  end

  context 'with loose foreign key on ci_secure_file_states.ci_secure_file_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent, freeze: true) { create(:ci_secure_file) }
      let_it_be(:model, freeze: true) { create(:geo_ci_secure_file_state, ci_secure_file: parent) }
    end
  end
end
