# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::References::LabelReferenceFilter, feature_category: :markdown do
  include FilterSpecHelper

  let(:project) { create(:project, :public, name: 'sample-project') }
  let(:description) { 'xss <script>alert("scriptAlert");</script> &<a>lt;svg id=&quot;svgId&quot;&gt;&lt;/svg&gt;' }
  let(:label) { create(:label, name: 'label', project: project, description: description) }
  let(:scoped_label) { create(:label, name: 'key::value', project: project, description: description) }

  context 'with scoped labels enabled' do
    before do
      stub_licensed_features(scoped_labels: true)
    end

    context 'with a scoped label' do
      let(:doc) { reference_filter("See #{scoped_label.to_reference}") }

      it 'renders scoped label' do
        expect(doc.css('.gl-label-scoped').text).to eq(scoped_label.scoped_label_key + scoped_label.scoped_label_value)
      end

      it 'renders HTML tooltips' do
        expect(doc.at_css('.gl-label-scoped a').attr('data-html')).to eq('true')
      end

      it "doesn't unescape HTML in the label's title" do
        # The `title` attribute's DOM value is interpreted as HTML in EE, so we expect it contains the
        # description escaped.
        title = doc.at_css('.gl-label-scoped a').attr('title')

        expect(title).to include('xss &lt;script&gt;alert')
        expect(title).to include('&amp;&lt;a&gt;lt;svg id=&amp;quot;svgId&amp;quot;&amp;gt;')
      end
    end

    context 'with a common label' do
      let(:doc) { reference_filter("See #{label.to_reference}") }

      it 'renders common label' do
        expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([label.name])
      end

      it 'renders HTML tooltips' do
        expect(doc.at_css('.gl-label a').attr('data-html')).to eq('true')
      end

      it "doesn't unescape HTML in the label's title" do
        title = doc.at_css('.gl-label a').attr('title')

        expect(title).to include('xss &lt;script&gt;alert')
        expect(title).to include('&amp;&lt;a&gt;lt;svg id=&amp;quot;svgId&amp;quot;&amp;gt;')
      end
    end
  end

  context 'with scoped labels disabled' do
    before do
      stub_licensed_features(scoped_labels: false)
    end

    it 'renders scoped label as a common label' do
      doc = reference_filter("See #{scoped_label.to_reference}")

      expect(doc.css('.gl-label .gl-label-text').map(&:text)).to eq([scoped_label.name])
    end
  end
end
