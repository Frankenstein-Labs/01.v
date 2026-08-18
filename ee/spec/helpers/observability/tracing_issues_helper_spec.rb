# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Observability::TracingIssuesHelper, feature_category: :observability do
  describe '#observability_tracing_issues_params' do
    let(:params) do
      {

        'fullUrl' => 'http://gdk.test:3443/flightjs/Flight/-/tracing/cd4cfff9-295b-f014-595c-1be1fc145822',
        'traceId' => 'cd4cfff9-295b-f014-595c-1be1fc145822',
        'duration' => '2.27ms',
        'name' => 'frontend-proxy : ingress',
        'start' => 'Thu, 04 Jul 2024 14:44:21 GMT',
        'totalErrors' => 0,
        'totalSpans' => 3
      }
    end

    context 'when params are blank' do
      it 'returns an empty hash' do
        expect(helper.observability_tracing_issues_params({})).to eq({})
        expect(helper.observability_tracing_issues_params(nil)).to eq({})
      end
    end

    context 'when params are present' do
      it 'returns the correct hash' do
        result = helper.observability_tracing_issues_params(params)

        expect(result[:title]).to eq("Issue created from trace 'frontend-proxy : ingress'")
        expect(result[:description]).to eq(
          <<~TEXT
            [Trace details](http://gdk.test:3443/flightjs/Flight/-/tracing/cd4cfff9-295b-f014-595c-1be1fc145822) \\
            Name: `frontend-proxy : ingress` \\
            Trace ID: `cd4cfff9-295b-f014-595c-1be1fc145822` \\
            Trace start: `Thu, 04 Jul 2024 14:44:21 GMT` \\
            Duration: `2.27ms` \\
            Total spans: `3` \\
            Total errors: `0`
          TEXT
        )
      end
    end
  end
end
