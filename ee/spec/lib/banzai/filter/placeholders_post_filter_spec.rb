# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::PlaceholdersPostFilter, feature_category: :markdown do
  def run_pipeline(text, context = { project: project })
    stub_commonmark_sourcepos_disabled

    Banzai.render_and_post_process(text, context)
  end

  let!(:latest_tag) do
    frag = Nokogiri::HTML.fragment("<span>")
    span = frag.children.first
    span['data-placeholder'] = '%{latest_tag}'
    span.content = project_tag
    frag.to_html
  end

  let!(:project_tag) do
    if project.repository_exists?
      TagsFinder.new(project.repository, per_page: 1, sort: 'updated_desc')&.execute&.first&.name
    end
  end

  context 'when tag has HTML' do
    let_it_be(:xss) do
      # We were once vulnerable to HTML entered directly, so we started sanitising it.
      # Unfortunately, in an HTML attribute (like 'title') there's no difference between
      # "<i>" and "&lt;i&gt;", but the latter doesn't get sanitised out when parsed as-is,
      # so the new attack just escapes the original! Test both.
      '<i/class=js-toggle-container><i/class=js-toggle-lazy-diff>' \
        '<i/class="file-holder"data-lines-path="/flightjs/xss/-/raw/main/a.json">' \
        '<i/class=gl-opacity-0><i/class="modal-backdrop"style="top&colon;-99px">' \
        '<i/class=diff-content><table><tbody/>' \
        '&lt;i/class=js-toggle-container&gt;&lt;i/class=js-toggle-lazy-diff&gt;' \
        '&lt;i/class="file-holder"data-lines-path="/group-x/b/-/raw/main/a.json"&gt;' \
        '&lt;i/class=gl-opacity-0&gt;&lt;i/class="modal-backdrop"style="top&colon;-99px"&gt;' \
        '&lt;i/class=diff-content&gt;&lt;table&gt;&lt;tbody/&gt;'
    end

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :small_repo, group: group, create_tag: xss) }
    let!(:scoped_label) { create(:label, name: 'key::value', description: 'xss %{latest_tag}', project: project) }

    before do
      stub_licensed_features(scoped_labels: true)

      project.add_member(user, Gitlab::Access::OWNER)
    end

    it "doesn't permit that HTML to enter the label title" do
      expect(Banzai::Filter::SanitizationFilter).to receive(:new).once.and_call_original

      markdown = '<span data-placeholder>foo ~"key::value"</span>'
      html = run_pipeline(markdown, project: project, current_user: user)

      frag = Nokogiri::HTML.fragment(html)
      title = frag.css('a[title][data-html="true"]').first['title']
      expect(title).not_to include("<i")
    end
  end
end
