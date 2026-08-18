# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PathLocksHelper do
  let(:user) { build_stubbed(:user, name: 'John') }
  let(:project) { build_stubbed(:project) }
  let(:path_lock) { build_stubbed(:path_lock, path: 'app', user: user, project: project) }

  describe '#can_unlock?' do
    it "returns true if the user can destroy_path_lock" do
      allow(self).to receive(:can?).with(user, :destroy_path_lock, path_lock).and_return(true)

      expect(can_unlock?(path_lock, user)).to be(true)
    end

    it "returns false if the user cannot destroy_path_lock" do
      allow(self).to receive(:can?).with(user, :destroy_path_lock, path_lock).and_return(false)

      expect(can_unlock?(path_lock, user)).to be(false)
    end
  end

  describe '#text_label_for_lock' do
    it "return correct string for non-nested locks" do
      expect(text_label_for_lock(path_lock, 'app')).to eq("Locked by #{user.username}")
    end

    it "return correct string for nested locks" do
      expect(text_label_for_lock(path_lock, 'app/models')).to eq("#{user.username} has a lock on \"app\"")
    end
  end
end
