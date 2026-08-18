# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::MigrationRemoveFieldsHelper, feature_category: :global_search do
  let(:migration_class) do
    Class.new do
      include ::Search::Elastic::MigrationRemoveFieldsHelper
    end
  end

  subject(:migration) { migration_class.new }

  describe '#fields_to_remove' do
    it 'raises a NotImplementedError' do
      expect { migration.fields_to_remove }.to raise_error(NotImplementedError)
    end
  end
end
