# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "shared/ee/_export_download_notice.html.haml", feature_category: :vulnerability_management do
  let(:export_url) { '/exports/123/download' }
  let(:exportable_link) { '<a href="/project/test">My Test</a>'.html_safe }
  let(:expiration_days) { 5 }
  let(:context_label) { 'Test Report' }

  let(:title_text) do
    s_('Vulnerabilities|The %{context_label} was successfully exported from %{exportable}.')
  end

  let(:download_text) do
    s_('Vulnerabilities|%{link_start}Download the export%{link_end}')
  end

  let(:expiration_text) do
    s_('Vulnerabilities|This link will expire in %{number} days.')
  end

  before do
    render partial: "shared/ee/export_download_notice", locals: {
      export_url: export_url,
      exportable_link: exportable_link,
      expiration_days: expiration_days,
      context_label: context_label,
      title_text: title_text,
      download_text: download_text,
      expiration_text: expiration_text
    }
  end

  it "renders the success message with exportable link" do
    expect(rendered).to include("The #{context_label} was successfully exported from")
    expect(rendered).to include(exportable_link)
  end

  it "renders a download button link with correct URL" do
    expect(rendered).to have_link('Download the export', href: export_url)
  end

  it "includes the expiration message" do
    expect(rendered).to include("This link will expire in #{expiration_days} days.")
  end

  it "applies expected inline styles" do
    expect(rendered).to include("display: inline-block")
    expect(rendered).to match(/style="[^"]*display:\s*inline-block[^"]*"/)
  end
end
