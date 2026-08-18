import { GlModal, GlSprintf } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserCapOverLicensedUsersModal from 'ee/pages/admin/application_settings/general/components/before_submit_user_cap_over_licensed_users_modal.vue';
import { stubComponent } from 'helpers/stub_component';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('UserCapOverLicensedUsersModal', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let addBeforeSubmitHook;
  let beforeSubmitHookContexts = {};

  const modalId = 'before-submit-modal-id';

  const findModal = () => wrapper.findComponent(GlModal);
  const verifyApproveUsers = () => addBeforeSubmitHook.mock.calls[0][0]();
  const modalStub = { show: jest.fn(), hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const createComponent = ({ provide = {} } = {}, mountFn = shallowMountExtended) => {
    addBeforeSubmitHook = jest.fn();

    wrapper = mountFn(UserCapOverLicensedUsersModal, {
      propsData: {
        id: modalId,
        licensedUserCount: 10,
        userCap: 13,
      },
      provide: {
        addBeforeSubmitHook,
        beforeSubmitHookContexts,
        ...provide,
      },
      stubs: {
        GlModal: GlModalStub,
        GlSprintf,
      },
    });
  };

  describe('when shouldPreventSubmit returns true', () => {
    beforeEach(() => {
      beforeSubmitHookContexts = { [modalId]: { shouldPreventSubmit: () => true } };
      createComponent();
      verifyApproveUsers();
    });

    it('shows the modal', () => {
      expect(modalStub.show).toHaveBeenCalled();
    });

    it('shows a title', () => {
      expect(findModal().props('title')).toBe('Proposed user cap exceeds licensed user count');
    });

    it('shows a text', () => {
      createComponent({}, mountExtended);
      verifyApproveUsers();

      expect(wrapper.text()).toBe(
        'Changing the user cap to 13 would exceed the licensed user count of 10, which may result in seat overages. Are you sure you want to proceed with the change?',
      );
    });

    it('shows a confirm button', () => {
      expect(findModal().props('actionPrimary').text).toBe('Proceed');
    });

    it('shows a cancel button', () => {
      expect(findModal().props('actionCancel').text).toBe('Cancel');
    });

    it('registers the hook', () => {
      expect(addBeforeSubmitHook).toHaveBeenCalledWith(expect.any(Function));
    });

    it.each(['hide', 'primary', 'secondary'])('emits %s event', (event) => {
      findModal().vm.$emit(event);

      expect(wrapper.emitted(event)).toHaveLength(1);
    });
  });

  describe('when shouldPreventSubmit returns false', () => {
    it('does not show the modal', () => {
      beforeSubmitHookContexts = { [modalId]: { shouldPreventSubmit: () => false } };
      createComponent();
      verifyApproveUsers();

      expect(modalStub.show).not.toHaveBeenCalled();
    });
  });

  describe('when shouldPreventSubmit is undefined', () => {
    it('does not show the modal', () => {
      beforeSubmitHookContexts = { [modalId]: {} };
      createComponent();
      verifyApproveUsers();

      expect(modalStub.show).not.toHaveBeenCalled();
    });
  });

  describe('when shouldPreventSubmit raises an error', () => {
    it('captures the error with Sentry', () => {
      const error = new Error('This is an error');
      beforeSubmitHookContexts = {
        [modalId]: {
          shouldPreventSubmit: () => {
            throw error;
          },
        },
      };
      createComponent();
      verifyApproveUsers();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });
});
