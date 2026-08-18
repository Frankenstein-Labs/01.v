# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRepositoryPolicy, feature_category: :container_registry do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, creator: user) }
  let_it_be(:container_repository) { create(:container_repository, project:) }

  subject { described_class.new(user, container_repository) }

  describe 'destroy_container_image' do
    context 'when the project has an immutable tag protection rule' do
      before_all do
        create(:container_registry_protection_tag_rule, :immutable, project:)
      end

      before do
        allow(container_repository).to receive(:has_tags?).and_return(has_tags)
      end

      context 'when the container repository has tags' do
        let(:has_tags) { true }

        %i[owner maintainer developer].each do |user_role|
          context "when the user is #{user_role}" do
            before do
              project.send(:"add_#{user_role}", user)
            end

            it { expect_allowed(:destroy_container_image) }
          end
        end

        context 'when the current user is an admin', :enable_admin_mode do
          let(:user) { build_stubbed(:admin) }

          it { expect_allowed(:destroy_container_image) }
        end
      end

      context 'when the container repository does not have tags' do
        let(:has_tags) { false }

        %i[owner maintainer developer].each do |user_role|
          context "when the user is #{user_role}" do
            before do
              project.send(:"add_#{user_role}", user)
            end

            it { expect_allowed(:destroy_container_image) }
          end
        end

        context 'when the current user is an admin', :enable_admin_mode do
          let(:user) { build_stubbed(:admin) }

          it { expect_allowed(:destroy_container_image) }
        end
      end
    end
  end
end
