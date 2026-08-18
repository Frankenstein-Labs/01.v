import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge, GlToggle } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SaasEnrollmentToggle from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_saas_enrollment_toggle.vue';
import enrollMutation from 'ee/ci/secrets/graphql/mutations/enroll_namespace_secrets_manager.mutation.graphql';
import unenrollMutation from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/unenroll_namespace_secrets_manager.mutation.graphql';
import { enrollNamespaceResponse, unenrollNamespaceResponse } from '../mock_data';

const mockToastShow = jest.fn();
Vue.use(VueApollo);

describe('SecretsManagerPermissionsSettings', () => {
  let wrapper;
  let mockApollo;
  let mockEnrollment;
  let mockUnenrollment;

  const createComponent = async ({ props, secretsManagerPaidExperience = false } = {}) => {
    const handlers = [
      [enrollMutation, mockEnrollment],
      [unenrollMutation, mockUnenrollment],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(SaasEnrollmentToggle, {
      apolloProvider: mockApollo,
      provide: {
        glFeatures: {
          secretsManagerPaidExperience,
        },
      },
      propsData: {
        canManageEnrollment: true,
        fullPath: '/path/to/group',
        hasEnrollmentQueryError: false,
        isEnrolled: false,
        disabled: false,
        ...props,
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });

    await waitForPromises();
    await nextTick();
  };

  const findBetaBadge = () => wrapper.findComponent(GlBadge);
  const findEnrollmentToggle = () => wrapper.findComponent(GlToggle);
  const findErrorMessage = () => wrapper.findByTestId('gsm-enrollment-error');

  const flipToggle = async () => {
    findEnrollmentToggle().vm.$emit('change');
    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockEnrollment = jest.fn().mockResolvedValue(enrollNamespaceResponse());
    mockUnenrollment = jest.fn().mockResolvedValue(unenrollNamespaceResponse());
  });

  describe('template', () => {
    it('disables toggle when user has no permission to manage enrollment', async () => {
      await createComponent({ props: { canManageEnrollment: false } });

      expect(findEnrollmentToggle().props('disabled')).toBe(true);
    });

    it('disables toggle when enrollment query fails', async () => {
      await createComponent({ props: { hasEnrollmentQueryError: true } });

      expect(findEnrollmentToggle().props('disabled')).toBe(true);
    });

    it('sets toggle value based on enrollment status', async () => {
      await createComponent({ props: { isEnrolled: true } });

      expect(findEnrollmentToggle().props('value')).toBe(true);
    });
  });

  describe('enrolling the namespace', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('disables the toggle while mutation is loading', async () => {
      expect(findEnrollmentToggle().props('disabled')).toBe(false);
      expect(findEnrollmentToggle().props('isLoading')).toBe(false);

      flipToggle();
      await nextTick();

      expect(findEnrollmentToggle().props('disabled')).toBe(true);
      expect(findEnrollmentToggle().props('isLoading')).toBe(true);
    });

    it('calls the mutation with the correct variables', () => {
      flipToggle();

      expect(mockEnrollment).toHaveBeenCalledWith({
        fullPath: '/path/to/group',
      });
    });

    describe('when enrollment succeeds', () => {
      beforeEach(async () => {
        await createComponent();
        await flipToggle();
      });

      it('emits toggled event', () => {
        expect(wrapper.emitted('toggled')).toHaveLength(1);
      });

      it('shows toast message', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          'GitLab Secrets Manager is enabled for this namespace.',
        );
      });

      it('resets toggle loading state', () => {
        expect(findEnrollmentToggle().props('isLoading')).toBe(false);
      });
    });

    describe('when enrollment fails', () => {
      beforeEach(async () => {
        mockEnrollment = jest
          .fn()
          .mockResolvedValue(
            enrollNamespaceResponse({ errors: ['Enrollment error message from API'] }),
          );

        await createComponent();
        await flipToggle();
      });

      it('shows error message', () => {
        expect(findErrorMessage().text()).toBe('Enrollment error message from API');
      });

      it('resets toggle loading state', () => {
        expect(findEnrollmentToggle().props('isLoading')).toBe(false);
      });
    });
  });

  describe('unenrolling the namespace', () => {
    beforeEach(async () => {
      await createComponent({ props: { isEnrolled: true } });
    });

    it('disables the toggle and sets loading state while mutation is loading', async () => {
      expect(findEnrollmentToggle().props('disabled')).toBe(false);
      expect(findEnrollmentToggle().props('isLoading')).toBe(false);

      findEnrollmentToggle().vm.$emit('change');
      await nextTick();

      expect(findEnrollmentToggle().props('disabled')).toBe(true);
      expect(findEnrollmentToggle().props('isLoading')).toBe(true);
    });

    it('calls the mutation with the correct variables', () => {
      findEnrollmentToggle().vm.$emit('change');

      expect(mockUnenrollment).toHaveBeenCalledWith({
        fullPath: '/path/to/group',
      });
    });

    describe('when unenrollment succeeds', () => {
      beforeEach(async () => {
        await createComponent({ props: { isEnrolled: true } });
        await flipToggle();
      });

      it('emits toggled event', () => {
        expect(wrapper.emitted('toggled')).toHaveLength(1);
      });

      it('shows toast message', () => {
        expect(mockToastShow).toHaveBeenCalledWith(
          'GitLab Secrets Manager is disabled for this namespace.',
        );
      });

      it('resets toggle loading state', () => {
        expect(findEnrollmentToggle().props('isLoading')).toBe(false);
      });
    });

    describe('when unenrollment fails', () => {
      beforeEach(async () => {
        mockUnenrollment = jest
          .fn()
          .mockResolvedValue(
            unenrollNamespaceResponse({ errors: ['Unenrollment error message from API'] }),
          );

        await createComponent({ props: { isEnrolled: true } });
        await flipToggle();
      });

      it('shows error message', () => {
        expect(findErrorMessage().text()).toBe('Unenrollment error message from API');
      });

      it('resets toggle loading state', () => {
        expect(findEnrollmentToggle().props('isLoading')).toBe(false);
      });
    });
  });

  describe('when secretsManagerPaidExperience feature flag is disabled', () => {
    beforeEach(async () => {
      await createComponent({ secretsManagerPaidExperience: false });
    });

    it('renders the open beta alert', () => {
      expect(findBetaBadge().exists()).toBe(true);
    });

    it('ignores disabled prop', async () => {
      await createComponent({
        secretsManagerPaidExperience: false,
        props: { disabled: true },
      });

      expect(findEnrollmentToggle().props('disabled')).toBe(false);
    });
  });

  describe('when secretsManagerPaidExperience feature flag is enabled', () => {
    it('does not render the open beta badge', async () => {
      await createComponent({ secretsManagerPaidExperience: true });

      expect(findBetaBadge().exists()).toBe(false);
    });

    it('disables toggle based on disabled prop value', async () => {
      await createComponent({
        secretsManagerPaidExperience: true,
        props: { disabled: true },
      });

      expect(findEnrollmentToggle().props('disabled')).toBe(true);
    });
  });
});
