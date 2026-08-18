import { GlButton } from '@gitlab/ui';
import StatusChecksTable from 'ee/projects/settings/branch_rules/components/status_checks/status_checks_table.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = (propsData) => {
    wrapper = shallowMountExtended(StatusChecksTable, {
      propsData: {
        statusChecks: statusChecksRulesMock,
        ...propsData,
      },
      stubs: {
        CrudComponent,
        GlButton,
      },
    });
  };

  const findAddButton = () => wrapper.findComponentByTestId('add-btn');
  const findEditButton = () => wrapper.findComponentByTestId('edit-btn');
  const findDeleteButton = () => wrapper.findComponentByTestId('delete-btn');
  const findCounterValue = () => wrapper.findByText(`${statusChecksRulesMock.length}`);
  const findStatusCheckEmptyState = () => wrapper.findByText('No status checks have been added.');

  beforeEach(() => createComponent());

  describe('renders correctly', () => {
    it('renders an empty state when there is no status checks', async () => {
      await createComponent({
        statusChecks: [],
      });
      expect(findStatusCheckEmptyState().exists()).toBe(true);
    });

    it('renders the correct status checks count', () => {
      expect(findCounterValue().exists()).toBe(true);
    });
  });

  describe('emits events to parent component', () => {
    it('emits add event when add button is clicked', () => {
      findAddButton().vm.$emit('click');
      expect(wrapper.emitted('open-status-check-drawer')).toEqual([[]]);
    });
    it('emits open event with status check when edit button is clicked', () => {
      findEditButton().vm.$emit('click');
      expect(wrapper.emitted('open-status-check-drawer')).toEqual([[statusChecksRulesMock[0]]]);
    });
    it('emits event to open delete modal when delete button is clicked', () => {
      findDeleteButton().vm.$emit('click');
      expect(wrapper.emitted('open-status-check-delete-modal')).toEqual([
        [statusChecksRulesMock[0]],
      ]);
    });
  });
});
