# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Exports::BatchDestroyService, '#execute', feature_category: :vulnerability_management do
  subject(:execute) { described_class.new(exports: vulnerabilities_export).execute }

  let(:vulnerabilities_export) { Vulnerabilities::Export.all }
  let(:uploads) { Upload }

  let(:vulnerabilities_export_count) { 2 }

  before do
    create_list(:vulnerability_export, vulnerabilities_export_count, :with_csv_file)
  end

  it 'deletes vulnerability exports', :sidekiq_inline do
    expect { execute }
      .to change { vulnerabilities_export.count }.from(vulnerabilities_export_count).to(0)
                                                 .and change { uploads.count }.from(vulnerabilities_export_count).to(0)
  end
end
