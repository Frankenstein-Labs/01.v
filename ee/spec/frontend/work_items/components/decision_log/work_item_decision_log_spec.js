import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemDecisionLog from 'ee/work_items/components/decision_log/work_item_decision_log.vue';
import DecisionLogItem from 'ee/work_items/components/decision_log/decision_log_item.vue';

describe('WorkItemDecisionLog', () => {
  let wrapper;

  const createComponent = () => {
    // The real CrudComponent renders the default slot, which is where the decisions live.
    wrapper = shallowMountExtended(WorkItemDecisionLog, {
      stubs: { CrudComponent },
    });
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findPendingSection = () => wrapper.findByTestId('pending-decisions');
  const findDecidedSection = () => wrapper.findByTestId('decided-decisions');
  const findAllItems = () => wrapper.findAllComponents(DecisionLogItem);

  beforeEach(() => {
    createComponent();
  });

  it('renders a collapsible section titled "Decision log"', () => {
    expect(findCrudComponent().props()).toMatchObject({
      title: 'Decision log',
      icon: 'documents',
      isCollapsible: true,
      persistCollapsedState: true,
      anchorId: 'decision-log',
    });
  });

  it('counts every decision in the log', () => {
    expect(findCrudComponent().props('count')).toBe(3);
    expect(findAllItems()).toHaveLength(3);
  });

  it('groups the undecided decisions under "Pending"', () => {
    expect(findPendingSection().find('h3').text()).toBe('Pending (1)');
    expect(findPendingSection().findAllComponents(DecisionLogItem)).toHaveLength(1);
  });

  it('groups the approved and rejected decisions under "Decided"', () => {
    expect(findDecidedSection().find('h3').text()).toBe('Decided (2)');
    expect(findDecidedSection().findAllComponents(DecisionLogItem)).toHaveLength(2);
  });

  it('numbers the decisions sequentially across both sections', () => {
    expect(findAllItems().wrappers.map((item) => item.props('reference'))).toEqual([
      'DL-001',
      'DL-002',
      'DL-003',
    ]);
  });

  it('passes each decision through to its item', () => {
    expect(findAllItems().at(0).props('decision')).toMatchObject({
      status: 'PENDING',
      category: 'SCOPE_DECISION',
    });
    expect(findAllItems().at(1).props('decision')).toMatchObject({
      status: 'APPROVED',
      category: 'AUTO_GENERATED',
    });
    expect(findAllItems().at(2).props('decision')).toMatchObject({
      status: 'REJECTED',
      category: 'QUESTION_RESOLVED',
    });
  });
});
