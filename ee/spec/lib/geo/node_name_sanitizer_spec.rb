# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::NodeNameSanitizer, feature_category: :geo_replication do
  let(:sanitizer) { described_class.new(name:) }

  describe '#name_without_slash' do
    context 'when name is nil' do
      let(:name) { nil }

      it 'returns the original name' do
        expect(sanitizer.name_without_slash).to be_nil
      end
    end

    context 'when name is empty' do
      let(:name) { '' }

      it 'returns the original name' do
        expect(sanitizer.name_without_slash).to eq('')
      end
    end

    context 'when name has a trailing slash' do
      let(:name) { 'https://example.com/' }

      it 'removes the last trailing slash' do
        expect(sanitizer.name_without_slash).to eq('https://example.com')
      end
    end

    context 'when name does not have a trailing slash' do
      let(:name) { 'https://example.com' }

      it 'returns the original name' do
        expect(sanitizer.name_without_slash).to eq('https://example.com')
      end
    end

    context 'when name is just a slash' do
      let(:name) { '/' }

      it 'returns an empty string' do
        expect(sanitizer.name_without_slash).to eq('')
      end
    end
  end

  describe '#name_with_slash' do
    context 'when name is nil' do
      let(:name) { nil }

      it 'returns the original name' do
        expect(sanitizer.name_with_slash).to be_nil
      end
    end

    context 'when name is empty' do
      let(:name) { '' }

      it 'returns the original name' do
        expect(sanitizer.name_with_slash).to eq('')
      end
    end

    context 'when name already ends with a slash' do
      let(:name) { 'https://example.com/' }

      it 'returns the original name unchanged' do
        expect(sanitizer.name_with_slash).to eq('https://example.com/')
      end
    end

    context 'when name does not end with a slash' do
      let(:name) { 'https://example.com' }

      it 'adds a slash to the end of the name' do
        expect(sanitizer.name_with_slash).to eq('https://example.com/')
      end
    end
  end

  describe '#match?' do
    let(:sanitizer) { described_class.new(name:, url:) }

    context 'when names are exactly equal' do
      let(:name) { 'https://example.com' }
      let(:url) { 'does not matter' }

      it 'returns true' do
        expect(sanitizer.match?(name)).to be true
      end
    end

    context 'when both name and url have trailing slashes' do
      context 'when name and value match' do
        let(:name) { 'https://example.com/' }
        let(:url) { 'https://example.com/' }
        let(:value) { 'https://example.com' }

        it 'returns true' do
          expect(sanitizer.match?(value)).to be true
        end
      end

      context 'when name and value do not match' do
        let(:name) { 'https://example.com/' }
        let(:url) { name }
        let(:value) { 'https://gitlab.org' }

        it 'returns false' do
          expect(sanitizer.match?(value)).to be false
        end
      end
    end

    context 'when name has a trailing slash and url matches with slash' do
      context 'when value matches url' do
        let(:name) { 'https://example.com' }
        let(:url) { 'https://example.com/' }
        let(:value) { url }

        it 'returns true' do
          expect(sanitizer.match?(value)).to be true
        end
      end

      context 'when value does not match name' do
        let(:name) { 'https://example.com' }
        let(:url) { 'https://example.com/' }
        let(:value) { 'https://gitlab.org' }

        it 'returns false' do
          expect(sanitizer.match?(value)).to be false
        end
      end
    end

    context 'with empty values' do
      let(:name) { '' }
      let(:url) { 'does not matter' }

      it 'returns true when comparing empty name with empty value' do
        expect(sanitizer.match?('')).to be true
      end

      it 'returns false when comparing empty name with non-empty value' do
        expect(sanitizer.match?('example.com')).to be false
      end
    end

    context 'with nil values' do
      let(:name) { nil }
      let(:url) { 'does not matter' }

      it 'handles nil name gracefully' do
        expect(sanitizer.match?(nil)).to be true
        expect(sanitizer.match?('something')).to be false
      end
    end
  end

  describe '#matched_name' do
    let(:sanitizer) { described_class.new(name:, url:) }

    context 'when both name and url have ending slashes' do
      let(:name) { 'https://example.com/' }
      let(:url) { 'https://example.com/' }

      it 'returns name without slash' do
        expect(sanitizer.sanitized_name).to eq(name.chomp('/'))
      end
    end

    context 'when name has no slash but url has a slash' do
      let(:name) { 'https://example.com' }

      context 'when url matches name' do
        let(:url) { 'https://example.com/' }

        it 'returns name with slash' do
          expect(sanitizer.sanitized_name).to eq("#{name}/")
        end
      end

      context 'when url does not match name' do
        let(:url) { 'https://gitlab.com/' }

        it 'returns name' do
          expect(sanitizer.sanitized_name).to eq(name)
        end
      end
    end

    context 'when name has a slash but url has no slash' do
      let(:name) { 'https://example.com/' }

      context 'when url matches name' do
        let(:url) { 'https://example.com' }

        it 'returns name without slash' do
          expect(sanitizer.sanitized_name).to eq(name.chomp('/'))
        end
      end

      context 'when url does not match name' do
        let(:url) { 'https://gitlab.com' }

        it 'returns name' do
          expect(sanitizer.sanitized_name).to eq(name)
        end
      end
    end

    context 'when neither condition is met' do
      let(:name) { 'my new site' }
      let(:url) { 'https://example.com/' }

      it 'returns the original name' do
        expect(sanitizer.sanitized_name).to eq(name)
      end
    end

    context 'when name is blank' do
      let(:name) { '' }
      let(:url) { 'https://example.com/' }

      it 'returns an empty string' do
        expect(sanitizer.sanitized_name).to eq('')
      end
    end
  end
end
