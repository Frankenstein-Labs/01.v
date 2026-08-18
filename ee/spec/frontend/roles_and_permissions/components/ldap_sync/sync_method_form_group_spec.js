import { GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SyncMethodFormGroup from 'ee/roles_and_permissions/components/ldap_sync/sync_method_form_group.vue';
import { glFormGroupStub, glRadioGroupStub } from './helpers';

describe('SyncMethodFormGroup component', () => {
  let wrapper;

  const createWrapper = ({ value, state = true, disabled = false } = {}) => {
    wrapper = shallowMountExtended(SyncMethodFormGroup, {
      propsData: { value, state, disabled },
      stubs: {
        GlFormGroup: glFormGroupStub,
        GlFormRadioGroup: glRadioGroupStub,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  describe('on page load', () => {
    beforeEach(() => createWrapper());

    it('shows form group', () => {
      expect(findFormGroup().props()).toMatchObject({
        label: 'Sync method',
        invalidFeedback: 'This field is required',
      });
    });

    it('shows the radio group', () => {
      expect(findRadioGroup().props()).toMatchObject({
        checked: null,
        options: [
          { value: 'group_cn', text: 'Group cn' },
          { value: 'user_filter', text: 'User filter' },
        ],
      });
    });

    it('emits input event when radio option is selected', () => {
      findRadioGroup().vm.$emit('input', 'group_cn');

      expect(wrapper.emitted('input')[0][0]).toBe('group_cn');
    });

    it.each([null, 'group_cn', 'user_filter'])('passes %s value to radio group', async (value) => {
      await wrapper.setProps({ value });

      expect(findRadioGroup().props('checked')).toBe(value);
    });

    it.each([true, false])('passes disabled prop with value %s to dropdown', async (disabled) => {
      await createWrapper({ disabled });

      expect(findRadioGroup().props('disabled')).toBe(disabled);
    });
  });

  describe.each`
    state    | radioGroupState
    ${true}  | ${null}
    ${false} | ${false}
  `('when state prop is $state', ({ state, radioGroupState }) => {
    beforeEach(() => createWrapper({ state }));

    it('passes state value to form group', () => {
      expect(findFormGroup().props('state')).toBe(state);
    });

    it('passes state value to radio group', () => {
      // GlFormRadioGroup has a styling bug where it shows green text if state is true, so we use null instead.
      expect(findRadioGroup().props('state')).toBe(radioGroupState);
    });
  });
});
