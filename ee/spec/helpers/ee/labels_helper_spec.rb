# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LabelsHelper, feature_category: :team_planning do
  let(:project) { create(:project) }
  let(:label) { build_stubbed(:label, project: project).present(issuable_subject: nil) }
  let(:scoped_label) { build_stubbed(:label, name: 'key::value', project: project).present(issuable_subject: nil) }

  describe '#render_label' do
    context 'with scoped labels disabled' do
      before do
        stub_licensed_features(scoped_labels: false)
      end

      it 'does not include link to scoped documentation' do
        expect(render_label(scoped_label)).to match(%r{<span.+><span.+>#{scoped_label.name}</span></span>$}m)
      end
    end

    context 'with the tooltip' do
      before do
        stub_licensed_features(scoped_labels: true)
      end

      subject(:title) do
        Nokogiri::HTML.fragment(render_label(label, link: '#')).at_css('a.gl-label-link')['data-title']
      end

      # The scoped label line (EE) and the archived line (CE) must render independently of each other.
      context 'when the label is scoped but not archived' do
        let(:label) do
          build_stubbed(:label, name: 'key::value', project: project, description: 'A description')
            .present(issuable_subject: nil)
        end

        it 'shows the scoped label line and no archived line' do
          expect(title).to eq('<span class="gl-font-bold">Scoped label</span><br>A description')
        end
      end

      context 'when the label is archived but not scoped' do
        let(:label) do
          build_stubbed(:label, name: 'plain', project: project, description: 'A description', archived: true)
            .present(issuable_subject: nil)
        end

        it 'shows the archived line and no scoped label line' do
          expect(title).to eq('A description<br><span class="gl-label-tooltip-footer">Archived</span>')
        end
      end

      context 'when the label is both scoped and archived' do
        let(:label) do
          build_stubbed(:label, name: 'key::value', project: project, description: 'A description', archived: true)
            .present(issuable_subject: nil)
        end

        it 'shows both the scoped label line and the archived line' do
          expect(title).to eq(
            '<span class="gl-font-bold">Scoped label</span><br>' \
              'A description<br><span class="gl-label-tooltip-footer">Archived</span>')
        end
      end
    end
  end

  describe '#wrap_label_html' do
    context 'when label is scoped label' do
      before do
        stub_licensed_features(scoped_labels: true)
      end

      let(:xss_label) do
        build_stubbed(:label, name: 'xss::label', project: project, color: '"><img src=x onerror=prompt(1)>')
      end

      it 'html-escapes the label color' do
        expect(wrap_label_html('xss', label: xss_label)).to include(html_escape(xss_label.color))
          .and include('color:')
      end
    end

    context 'when label is not scoped label' do
      before do
        stub_licensed_features(scoped_labels: false)
      end

      let(:xss_label) do
        build_stubbed(:label, name: 'xsslabel', project: project, color: '"><img src=x onerror=prompt(1)>')
      end

      it 'does not include the color' do
        expect(wrap_label_html('xss', label: xss_label)).not_to include('color:')
      end
    end
  end

  describe '#label_dropdown_data' do
    subject { label_dropdown_data(edit_context, opts) }

    let(:opts) { { default_label: "Labels" } }
    let(:data) do
      {
        toggle: "dropdown",
        field_name: opts[:field_name] || "label_name[]",
        show_no: "true",
        show_any: "true",
        default_label: "Labels",
        scoped_labels: "false"
      }
    end

    context 'when edit_context is a project' do
      let(:edit_context) { create(:project) }
      let(:label) { create(:label, project: edit_context, title: 'bug') }

      before do
        data.merge!({
          project_id: edit_context.id,
          namespace_path: edit_context.namespace.full_path,
          project_path: edit_context.path
        })
      end

      it { is_expected.to eq(data) }
    end

    context 'when edit_context is a group' do
      let(:edit_context) { create(:group) }
      let(:label) { create(:group_label, group: edit_context, title: 'bug') }

      before do
        data.merge!(group_id: edit_context.id)
      end

      it { is_expected.to eq(data) }
    end
  end

  describe '#labels_function_introduction' do
    subject { helper.labels_function_introduction }

    let(:group) { instance_double(Group) }

    context 'when epics is unavailable' do
      before do
        allow(group).to receive(:feature_available?).with(:epics).and_return(false)
        assign(:group, group)
      end

      it do
        expect_text = _('Labels can be applied to issues and merge requests. '\
          'Group labels are available for any project within the group.')
        is_expected.to eq(expect_text)
      end
    end

    context 'when epics is available' do
      before do
        allow(group).to receive(:feature_available?).with(:epics).and_return(true)
        assign(:group, group)
      end

      it do
        expect_text = _('Labels can be applied to issues, merge requests, and epics. '\
          'Group labels are available for any project within the group.')
        is_expected.to eq(expect_text)
      end
    end
  end

  describe '#label_tooltip_title_html' do
    let(:description) { '<img src="example.png">This is an image</img>' }
    let(:label_with_html_content) { build_stubbed(:label, title: title, description: description) }
    let(:tooltip) { label_tooltip_title_html(label_with_html_content) }

    context 'when label is unscoped' do
      let(:title) { 'test' }

      it 'escapes HTML for display' do
        expect(tooltip).to eq('&lt;img src=&quot;example.png&quot;&gt;This is an image&lt;/img&gt;')
      end
    end

    context 'when label is scoped' do
      let(:title) { 'scope::test' }

      it 'includes scoped label tag and escapes HTML for display' do
        expect(tooltip).to eq(
          '<span class="gl-font-bold">Scoped label</span><br>' \
            '&lt;img src=&quot;example.png&quot;&gt;This is an image&lt;/img&gt;')
      end
    end

    context 'when label is scoped and archived' do
      let(:label_with_html_content) do
        build_stubbed(:label, title: 'scope::test', description: 'A description', archived: true)
      end

      it 'shows the scoped label tag on top and the archived line at the bottom' do
        expect(tooltip).to eq(
          '<span class="gl-font-bold">Scoped label</span><br>' \
            'A description<br><span class="gl-label-tooltip-footer">Archived</span>')
      end
    end

    context 'when label is scoped and archived with tooltip_shows_title' do
      let(:label_with_html_content) do
        build_stubbed(:label, title: 'scope::test', description: 'A description', archived: true)
      end

      it 'shows the title instead of the description' do
        result = label_tooltip_title_html(label_with_html_content, tooltip_shows_title: true)

        expect(result).to eq(
          '<span class="gl-font-bold">Scoped label</span><br>' \
            'scope::test<br><span class="gl-label-tooltip-footer">Archived</span>')
      end
    end
  end
end
