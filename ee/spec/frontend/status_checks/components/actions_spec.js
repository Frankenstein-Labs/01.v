import { GlButton } from '@gitlab/ui';
import Actions from 'ee/status_checks/components/actions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

const statusCheck = {
  externalUrl: 'https://foo.com',
  id: 1,
  name: 'Foo',
  protectedBranches: [],
};

describe('Status checks actions', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMountExtended(Actions, {
      propsData: {
        statusCheck,
      },
      stubs: {
        GlButton,
      },
    });
  };

  beforeEach(() => {
    createWrapper();
  });

  const findEditBtn = () => wrapper.findComponentByTestId('edit-btn');
  const findDeleteBtn = () => wrapper.findComponentByTestId('delete-btn');

  describe.each`
    ariaLabel   | button           | event
    ${'Edit'}   | ${findEditBtn}   | ${'open-update-modal'}
    ${'Delete'} | ${findDeleteBtn} | ${'open-delete-modal'}
  `('$text button', ({ ariaLabel, button, event }) => {
    it(`renders the button with the aria-label '${ariaLabel}'`, () => {
      expect(button().attributes('aria-label')).toBe(ariaLabel);
    });

    it(`sends the status check with the '${event}' event`, () => {
      button().vm.$emit('click');

      expect(wrapper.emitted(event)[0][0]).toStrictEqual(statusCheck);
    });
  });
});
