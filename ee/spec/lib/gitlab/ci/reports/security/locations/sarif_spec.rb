# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Reports::Security::Locations::Sarif, feature_category: :vulnerability_management do
  let(:params) do
    {
      file_path: 'app/models/user.rb',
      start_line: 42,
      end_line: 42,
      start_column: 5,
      end_column: 50
    }
  end

  it_behaves_like 'vulnerability location' do
    let(:mandatory_params) { %i[file_path] }
    # rubocop:disable Fips/SHA1 -- fingerprint uses SHA1 internally; must match for shared example
    let(:expected_fingerprint) { Digest::SHA1.hexdigest('app/models/user.rb:42:42') }
    # rubocop:enable Fips/SHA1
    let(:expected_fingerprint_path) { 'user.rb' }
  end

  describe '#fingerprint_data' do
    it 'includes file_path, start_line, and end_line' do
      location = described_class.new(**params)

      expect(location.fingerprint_data).to eq('app/models/user.rb:42:42')
    end

    context 'with nil lines' do
      it 'produces a degenerate but stable fingerprint' do
        location = described_class.new(file_path: 'app/models/user.rb')

        expect(location.fingerprint_data).to eq('app/models/user.rb::')
      end
    end
  end

  describe '#start_line and #end_line' do
    it 'coerces values to integers' do
      location = described_class.new(file_path: 'app/models/user.rb', start_line: '10', end_line: '20')

      expect(location.start_line).to eq(10)
      expect(location.end_line).to eq(20)
    end
  end
end
