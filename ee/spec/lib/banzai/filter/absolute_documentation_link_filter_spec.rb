# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::AbsoluteDocumentationLinkFilter, feature_category: :duo_chat do
  let(:context) { { base_url: base_url } }
  let(:base_url) { "http://localhost:3001/help/api/repositories" }
  let(:host_url) { 'https://gitlab.com' }

  subject { described_class.call(doc, context).at_css('a')['href'] }

  before do
    allow(Gitlab.config.gitlab).to receive(:url).and_return(host_url)
  end

  context 'without a base_url' do
    let(:doc) { %(<a href="../foo">Link</a>) }

    context 'when when base_url is not given' do
      let(:context) { {} }

      it { is_expected.to eq "../foo" }
    end

    context 'when base_url is nil' do
      let(:base_url) { nil }

      it { is_expected.to eq "../foo" }
    end

    context 'when base_url is empty' do
      let(:base_url) { "" }

      it { is_expected.to eq "../foo" }
    end
  end

  context 'with a base_url' do
    context 'when it contains a relative link with a .md file extension' do
      let(:base_url) { "http://localhost:3001/help/user/project/repository/forking_workflow" }
      let(:doc) { %(<a href="../../namespace/index.md">Link</a>) }

      it { is_expected.to eq "https://gitlab.com/help/user/namespace/index.html" }
    end

    context 'when it contains an absolute link' do
      let(:doc) { %(<a href="https://about.gitlab.com/why-gitlab">Link</a>) }

      it { is_expected.to eq "https://about.gitlab.com/why-gitlab" }
    end
  end
end
