# frozen_string_literal: true
require 'spec_helper'

RSpec.describe PathLockPolicy, feature_category: :source_code_management do
  let(:project) { create(:project) }
  let(:maintainer) { create(:user) }
  let(:developer) { create(:user) }
  let(:non_member) { create(:user) }

  let(:developer_path_lock) { create(:path_lock, user: developer, project: project) }
  let(:non_member_path_lock) { create(:path_lock, user: non_member, project: project) }

  before do
    project.add_maintainer(maintainer)
    project.add_developer(developer)
  end

  subject(:policy) { described_class.new(user, path_lock) }

  context 'with a non-member' do
    let(:user) { non_member }

    context 'and a path lock they created' do
      let(:path_lock) { non_member_path_lock }

      it { is_expected.to be_disallowed(:destroy_path_lock) }
    end
  end

  context 'with a developer' do
    let(:user) { developer }

    context 'and a path lock they created' do
      let(:path_lock) { developer_path_lock }

      it { is_expected.to be_allowed(:destroy_path_lock) }
    end

    context 'and path lock they did not create' do
      let(:path_lock) { non_member_path_lock }

      it { is_expected.to be_disallowed(:destroy_path_lock) }
    end
  end

  context 'with a maintainer' do
    let(:user) { maintainer }

    context 'and a path lock they did not create' do
      let(:path_lock) { non_member_path_lock }

      it { is_expected.to be_allowed(:destroy_path_lock) }
    end
  end
end
