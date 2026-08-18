import { mountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import DecisionLogItem from 'ee/work_items/components/decision_log/decision_log_item.vue';

describe('DecisionLogItem', () => {
  let wrapper;

  const buildDecision = (overrides = {}) => ({
    id: 'gid://gitlab/WorkItems::Decision/1',
    title: 'Should the decision log be available on epics?',
    status: 'PENDING',
    category: 'SCOPE_DECISION',
    createdAt: '2026-08-01T10:00:00Z',
    decidedAt: null,
    author: { id: 'gid://gitlab/User/1', name: 'Sidney Jones' },
    assignee: null,
    selectedOption: null,
    ...overrides,
  });

  const createComponent = ({ decision = buildDecision(), reference = 'DL-001' } = {}) => {
    wrapper = mountExtended(DecisionLogItem, {
      propsData: { decision, reference },
    });
  };

  const findItem = () => wrapper.findByTestId('decision-log-item');
  const findStatusIcon = () => wrapper.findComponentByTestId('decision-status-icon');
  const findCategoryBadge = () => wrapper.findComponentByTestId('decision-category');
  const findStatusBadge = () => wrapper.findComponentByTestId('decision-status');
  const findTimeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const findAssignee = () => wrapper.findByTestId('decision-assignee');
  const findSelectedOption = () => wrapper.findByTestId('decision-selected-option');

  it('renders the author, title and reference', () => {
    createComponent();

    expect(wrapper.findByTestId('decision-author').text()).toBe('Sidney Jones');
    expect(wrapper.findByTestId('decision-title').text()).toBe(
      'Should the decision log be available on epics?',
    );
    expect(wrapper.findByTestId('decision-reference').text()).toBe('DL-001');
  });

  describe('status', () => {
    it.each`
      status                  | label                   | icon                     | variant
      ${'PENDING'}            | ${'Pending'}            | ${'status-neutral'}      | ${'warning'}
      ${'APPROVAL_REQUESTED'} | ${'Approval requested'} | ${'status-waiting'}      | ${'info'}
      ${'APPROVED'}           | ${'Approved'}           | ${'check-circle-filled'} | ${'success'}
      ${'REJECTED'}           | ${'Rejected'}           | ${'status-cancelled'}    | ${'danger'}
    `('renders $label with the $icon icon for $status', ({ status, label, icon, variant }) => {
      createComponent({ decision: buildDecision({ status }) });

      expect(findStatusBadge().text()).toBe(label);
      expect(findStatusBadge().props('variant')).toBe(variant);
      expect(findStatusIcon().props('name')).toBe(icon);
      expect(findStatusIcon().attributes('aria-label')).toBe(label);
    });

    it('falls back to the raw value for an unrecognised status', () => {
      createComponent({ decision: buildDecision({ status: 'SOMETHING_NEW' }) });

      expect(findStatusBadge().text()).toBe('SOMETHING_NEW');
      expect(findStatusBadge().props('variant')).toBe('neutral');
      expect(findStatusIcon().props('name')).toBe('status-neutral');
    });
  });

  describe('category', () => {
    it.each`
      category               | label                  | variant
      ${'SCOPE_DECISION'}    | ${'Scope decision'}    | ${'neutral'}
      ${'REQUIREMENT_ADDED'} | ${'Requirement added'} | ${'neutral'}
      ${'QUESTION_RESOLVED'} | ${'Question resolved'} | ${'success'}
      ${'AUTO_GENERATED'}    | ${'Auto-generated'}    | ${'info'}
    `('renders $label for $category', ({ category, label, variant }) => {
      createComponent({ decision: buildDecision({ category }) });

      expect(findCategoryBadge().text()).toBe(label);
      expect(findCategoryBadge().props('variant')).toBe(variant);
    });

    it('falls back to the raw value for an unrecognised category', () => {
      createComponent({ decision: buildDecision({ category: 'SOMETHING_NEW' }) });

      expect(findCategoryBadge().text()).toBe('SOMETHING_NEW');
      expect(findCategoryBadge().props('variant')).toBe('neutral');
    });
  });

  describe('when the decision is pending', () => {
    it('highlights the item', () => {
      createComponent({ decision: buildDecision({ status: 'PENDING' }) });

      expect(findItem().classes()).toEqual(
        expect.arrayContaining(['gl-bg-status-warning', 'gl-border-feedback-warning']),
      );
    });

    it('shows when the decision was raised', () => {
      createComponent({ decision: buildDecision({ status: 'PENDING' }) });

      expect(findTimeAgo().props('time')).toBe('2026-08-01T10:00:00Z');
    });

    it('does not show a selected option even when one is set', () => {
      createComponent({
        decision: buildDecision({
          status: 'PENDING',
          selectedOption: { id: 'gid://gitlab/WorkItems::DecisionOption/1', text: 'Widget' },
        }),
      });

      expect(findSelectedOption().exists()).toBe(false);
    });
  });

  describe('when the decision has been decided', () => {
    const decidedDecision = buildDecision({
      status: 'APPROVED',
      decidedAt: '2026-08-05T10:00:00Z',
      selectedOption: {
        id: 'gid://gitlab/WorkItems::DecisionOption/1',
        text: 'Widget below the description',
      },
    });

    it('does not highlight the item', () => {
      createComponent({ decision: decidedDecision });

      expect(findItem().classes()).toContain('gl-bg-default');
      expect(findItem().classes()).not.toContain('gl-bg-status-warning');
    });

    it('shows when the decision was decided rather than raised', () => {
      createComponent({ decision: decidedDecision });

      expect(findTimeAgo().props('time')).toBe('2026-08-05T10:00:00Z');
    });

    it('shows the selected option', () => {
      createComponent({ decision: decidedDecision });

      expect(findSelectedOption().text()).toBe('Selected: Widget below the description');
    });

    it('does not show a selected option when none was recorded', () => {
      createComponent({ decision: buildDecision({ status: 'REJECTED', selectedOption: null }) });

      expect(findSelectedOption().exists()).toBe(false);
    });
  });

  describe('assignee', () => {
    it('shows who the decision is waiting on', () => {
      createComponent({
        decision: buildDecision({ assignee: { id: 'gid://gitlab/User/2', name: 'Zhang Wei' } }),
      });

      expect(findAssignee().text()).toBe('Awaiting Zhang Wei');
    });

    it('is not rendered when the decision is unassigned', () => {
      createComponent({ decision: buildDecision({ assignee: null }) });

      expect(findAssignee().exists()).toBe(false);
    });
  });
});
