# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceWeightEventPolicy, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let(:iteration) { build_stubbed(:iteration, group: project.group) }
  let(:event) { build(:resource_iteration_event, issue: issue, iteration: iteration) }

  describe '#read_resource_weight_event' do
    context 'with non-member user' do
      it 'does not allow to read event' do
        expect(permissions(user, event)).to be_disallowed(:read_resource_weight_event, :read_note)
      end
    end

    context 'with member user' do
      before_all do
        project.add_guest(user)
      end

      it 'allows to read event for accessible iteration' do
        expect(permissions(user, event)).to be_allowed(:read_resource_weight_event, :read_note)
      end
    end
  end

  def permissions(user, issue)
    described_class.new(user, issue)
  end
end
