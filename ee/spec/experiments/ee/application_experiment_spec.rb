# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ApplicationExperiment, :experiment, feature_category: :acquisition do
  subject(:application_experiment) { described_class.new('namespaced/stub', **context) }

  let(:context) { {} }
  let(:feature_definition) { { name: 'namespaced_stub', type: 'experiment', default_enabled: false } }

  before do
    stub_feature_flag_definition(:namespaced_stub, feature_definition)

    allow(Gitlab::FIPS).to receive(:enabled?).and_return(true)
    allow(application_experiment).to receive(:enabled?).and_return(true)
  end

  describe "#process_redirect_url" do
    using RSpec::Parameterized::TableSyntax

    where(:url, :processed_url) do
      'https://about.gitlab.com/'                 | 'https://about.gitlab.com/'
      'https://gitlab.com/'                       | 'https://gitlab.com/'
      'http://docs.gitlab.com'                    | 'http://docs.gitlab.com'
      'https://docs.gitlab.com/some/path?foo=bar' | 'https://docs.gitlab.com/some/path?foo=bar'
      'http://badgitlab.com'                      | nil
      'https://gitlab.com.nefarious.net'          | nil
      'https://unknown.gitlab.com'                | nil
      "https://badplace.com\nhttps://gitlab.com"  | nil
      'https://gitlabbcom'                        | nil
      'https://gitlabbcom/'                       | nil
      'http://gdk.test/foo/bar'                   | 'http://gdk.test/foo/bar'
      'http://localhost:3000/foo/bar'             | 'http://localhost:3000/foo/bar'
    end

    with_them do
      it "returns the url or nil if invalid on SaaS" do
        stub_saas_features(experimentation: true)

        expect(application_experiment.process_redirect_url(url)).to eq(processed_url)
      end
    end

    it "considers all urls invalid when not on SaaS" do
      stub_saas_features(experimentation: false) # ignored when in FOSS only test runs

      expect(application_experiment.process_redirect_url('https://about.gitlab.com/')).to be_nil
    end
  end

  describe ".available?" do
    let(:experimentation_enabled) { true }

    before do
      stub_saas_features(experimentation: experimentation_enabled)
    end

    context "when saas feature is available" do
      it "is true" do
        expect(described_class).to be_available
      end
    end

    context "when saas feature is not available" do
      let(:experimentation_enabled) { false }

      it "is false" do
        expect(described_class).not_to be_available
      end
    end
  end
end
