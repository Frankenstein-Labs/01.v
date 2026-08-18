import { shallowMount } from '@vue/test-utils';
import { GlModal, GlSprintf } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import ExclusionDeleteModal from 'ee/security_configuration/secret_detection/components/exclusion_delete_modal.vue';
import deleteMutation from 'ee/security_configuration/secret_detection/graphql/project_security_exclusion_delete.mutation.graphql';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

jest.mock('~/alert');

const mutateDelete = jest.fn().mockResolvedValue({
  data: {
    projectSecurityExclusionDelete: {
      errors: [],
    },
  },
});

describe('ExclusionDeleteModal', () => {
  let wrapper;
  let apolloProvider;

  const showMock = jest.fn();

  const mockExclusion = {
    id: 'gid/1',
    type: 'PATH',
    value: 'test',
    description: 'description',
    scanner: 'SECRET_PUSH_PROTECTION',
    active: true,
  };

  const createComponent = ({ props = {}, resolver = mutateDelete } = {}) => {
    apolloProvider = createMockApollo([[deleteMutation, resolver]]);

    wrapper = shallowMount(ExclusionDeleteModal, {
      apolloProvider,
      propsData: {
        exclusion: mockExclusion,
        ...props,
      },
      mocks: {
        $toast: {
          show: showMock,
        },
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the GlModal component', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('sets the correct title for the modal', () => {
      expect(findModal().props('title')).toBe('Delete exclusion');
    });

    it('renders the correct description', () => {
      const text = `You are about to delete the path \`${mockExclusion.value}\` from the secret detection exclusions. Are you sure you want to continue?`;

      expect(findModal().text()).toContain(text);
    });
  });

  describe('on deletion', () => {
    it('trigger the mutation with correct input', async () => {
      findModal().vm.$emit('primary');
      await waitForPromises();

      expect(mutateDelete).toHaveBeenCalledWith({
        input: {
          id: mockExclusion.id,
        },
      });

      expect(showMock).toHaveBeenCalled();
    });

    it('captures exception in Sentry when unexpected error occurs', async () => {
      jest.spyOn(Sentry, 'captureException');
      const mockErrorResolver = jest.fn().mockRejectedValue(new Error('Unexpected error'));

      createComponent({ resolver: mockErrorResolver });

      await findModal().vm.$emit('primary');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Unexpected error',
          title: 'Failed to delete the exclusion:',
        }),
      );

      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Unexpected error'));
    });

    it('displays an error message when deletion fails', async () => {
      const errorMessage = 'Something went wrong';
      const mockErrorResolver = jest.fn().mockResolvedValue({
        data: {
          projectSecurityExclusionDelete: {
            errors: [errorMessage],
          },
        },
      });

      createComponent({ resolver: mockErrorResolver });
      await findModal().vm.$emit('primary');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        title: 'Failed to delete the exclusion:',
      });
    });
  });
});
