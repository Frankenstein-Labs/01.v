# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ArchiveExportPolicy, feature_category: :vulnerability_management do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:archive_export) { create(:vulnerability_archive_export, project: project, author: author) }

  subject { described_class.new(user, archive_export) }

  context 'when security dashboard is licensed' do
    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user is the author of the archive export' do
      let(:author) { user }

      context 'when user has access to vulnerabilities from the project' do
        before_all do
          project.add_developer(user)
        end

        it { is_expected.to be_allowed(:read_vulnerability_archive_export) }
      end

      context 'when user has no access to vulnerabilities from the project' do
        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end
    end

    context 'when the user is not the author of the archive export' do
      let(:author) { create(:user) }

      context 'when user has access to vulnerabilities from the project' do
        before_all do
          project.add_developer(user)
        end

        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end

      context 'when user has no access to vulnerabilities from the project' do
        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end
    end
  end

  context 'when security dashboard is not licensed' do
    before do
      stub_licensed_features(security_dashboard: false)
    end

    context 'when the user is the author of the archive export' do
      let(:author) { user }

      context 'when user has access to vulnerabilities from the project' do
        before_all do
          project.add_developer(user)
        end

        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end

      context 'when user has no access to vulnerabilities from the project' do
        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end
    end

    context 'when the user is not the author of the archive export' do
      let(:author) { create(:user) }

      context 'when user has access to vulnerabilities from the project' do
        before_all do
          project.add_developer(user)
        end

        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end

      context 'when user has no access to vulnerabilities from the project' do
        it { is_expected.to be_disallowed(:read_vulnerability_archive_export) }
      end
    end
  end
end
