import { GlFormGroup, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserFilterFormGroup from 'ee/roles_and_permissions/components/ldap_sync/user_filter_form_group.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { glFormGroupStub, glFormTextareaStub } from './helpers';

describe('UserFilterFormGroup component', () => {
  let wrapper;

  const createWrapper = ({ value, state = true, disabled = false } = {}) => {
    wrapper = shallowMountExtended(UserFilterFormGroup, {
      propsData: { value, state, disabled },
      stubs: {
        GlSprintf,
        GlFormGroup: glFormGroupStub,
        GlFormTextarea: glFormTextareaStub,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findTextarea = () => wrapper.findComponent(GlFormTextarea);

  describe('on page load', () => {
    beforeEach(() => createWrapper());

    describe('form group', () => {
      it('shows form group', () => {
        expect(findFormGroup().props()).toMatchObject({
          label: 'User filter',
          invalidFeedback: 'This field is required',
        });
      });

      it('shows description', () => {
        expect(wrapper.findByTestId('slot-label-description').text()).toBe(
          'View more information on user filters.',
        );
      });

      it('shows help page link', () => {
        const link = findFormGroup().findComponent(HelpPageLink);

        expect(link.text()).toBe('user filters');
        expect(link.attributes('href')).toBe('administration/auth/ldap/_index');
      });
    });

    describe('textarea', () => {
      it('shows the textarea', () => {
        expect(findTextarea().attributes('class')).toBe('gl-max-w-48');
        expect(findTextarea().props()).toMatchObject({
          value: null,
          rows: 2,
          noResize: false,
          placeholder: 'Start typing',
        });
      });

      it('emits input event when textarea is updated', () => {
        findTextarea().vm.$emit('update', 'uid=john,ou=people,dc=example,dc=com');

        expect(wrapper.emitted('input')[0][0]).toBe('uid=john,ou=people,dc=example,dc=com');
      });

      it('sends value prop to textarea', async () => {
        await wrapper.setProps({ value: 'some text' });

        expect(findTextarea().props('value')).toBe('some text');
      });

      it.each([true, false])('passes disabled prop with value %s to dropdown', async (disabled) => {
        await wrapper.setProps({ disabled });

        expect(findTextarea().props('disabled')).toBe(disabled);
      });
    });
  });

  describe.each([true, false])('when state prop is %s', (state) => {
    beforeEach(() => createWrapper({ state }));

    it('passes state value to form group', () => {
      expect(findFormGroup().props('state')).toBe(state);
    });

    it('passes state value to radio group', () => {
      expect(findTextarea().props('state')).toBe(state);
    });
  });
});
