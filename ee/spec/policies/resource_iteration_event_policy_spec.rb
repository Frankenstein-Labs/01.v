# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceIterationEventPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:private_project) { create(:project, :private, group: private_group) }

  subject { described_class.new(user, event) }

  describe '#read_resource_iteration_event' do
    context 'with non-member user' do
      let(:event) { build_event(project) }

      it 'does not allow to read event' do
        expect_disallowed(:read_resource_iteration_event, :read_note)
      end
    end

    context 'with member user' do
      before_all do
        project.add_guest(user)
      end

      context 'for accessible iteration' do
        let(:event) { build_event(project) }

        it 'allows to read event' do
          expect_allowed(:read_resource_iteration_event, :read_note)
        end
      end

      context 'for not accessible iteration' do
        let(:event) { build_event(private_project) }

        it 'does not allow to read event' do
          expect_disallowed(:read_resource_iteration_event, :read_note)
        end
      end
    end
  end

  describe '#read_iteration' do
    before_all do
      project.add_guest(user)
    end

    context 'with deleted iteration' do
      let(:event) { build(:resource_iteration_event, issue: issue, iteration: nil) }

      it 'allows to read deleted iteration' do
        expect_allowed(:read_iteration, :read_resource_iteration_event, :read_note)
      end
    end

    context 'with accessible iteration' do
      let(:event) { build_event(project) }

      it 'allows to read accessible iteration' do
        expect_allowed(:read_iteration, :read_resource_iteration_event, :read_note)
      end
    end

    context 'with not accessible iteration' do
      let(:event) { build_event(private_project) }

      it 'does not allow to read not accessible iteration' do
        expect_disallowed(:read_iteration, :read_resource_iteration_event, :read_note)
      end
    end
  end

  def build_event(project)
    iteration = create(:iteration, group: project.group)

    build(:resource_iteration_event, issue: issue, iteration: iteration)
  end
end
