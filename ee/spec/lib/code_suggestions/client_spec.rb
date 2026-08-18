# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Client, feature_category: :code_suggestions do
  let(:headers) { {} }
  let(:client) { described_class.new(headers) }

  describe '#supports_sse_streaming?' do
    using RSpec::Parameterized::TableSyntax

    subject(:supports_sse_streaming?) { client.supports_sse_streaming? }

    where(:header_value, :expected_bool) do
      nil    | false
      ''     | false
      '0'    | false
      'true' | true
      'True' | true
      '1'    | true
      'abc'  | false
    end

    with_them do
      it 'returns the expected boolean based on the header value of `X-Supports-Sse-Streaming`' do
        headers['X-Supports-Sse-Streaming'] = header_value

        is_expected.to be(expected_bool)
      end
    end
  end
end
