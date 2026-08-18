import StatusChecksDrawer from 'ee/projects/settings/branch_rules/components/status_checks/status_checks_drawer.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(StatusChecksDrawer, {
      propsData,
    });
  };

  const findStatusChecksForm = () => wrapper.findComponentByTestId('status-checks-form');
  const findAddStatusCheckHeader = () => wrapper.findByText('Add status check');
  const findEditStatusCheckHeader = () => wrapper.findByText('Edit status check');

  beforeEach(() => createComponent());

  describe('emits events to parent component', () => {
    it('emits event with create type when there is no status check selected', () => {
      expect(findAddStatusCheckHeader().exists()).toBe(true);
      findStatusChecksForm().vm.$emit('save-status-check-change', statusChecksRulesMock[0]);
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [statusChecksRulesMock[0], 'create'],
      ]);
    });

    it('emits event with edit type when there is a status check selected', async () => {
      await createComponent({ propsData: { selectedStatusCheck: statusChecksRulesMock[0] } });
      expect(findEditStatusCheckHeader().exists()).toBe(true);
      findStatusChecksForm().vm.$emit('save-status-check-change', statusChecksRulesMock[0]);
      expect(wrapper.emitted('save-status-check-change')).toEqual([
        [statusChecksRulesMock[0], 'edit'],
      ]);
    });

    it('emits close drawer event', () => {
      findStatusChecksForm().vm.$emit('close-status-check-drawer');
      expect(wrapper.emitted('close-status-check-drawer')).toEqual([[]]);
    });
  });
});
