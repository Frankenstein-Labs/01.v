import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import getProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import CiEnvironmentsDropdown, {
  ENVIRONMENT_FETCH_ERROR,
  getGroupEnvironments,
  getProjectEnvironments,
} from '~/ci/common/private/ci_environments_dropdown';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  ENTITLEMENT_STATE_TRIAL_ELIGIBLE,
  ENTITY_GROUP,
  ENTITY_PROJECT,
  INDEX_ROUTE_NAME,
} from 'ee/ci/secrets/constants';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import createMockApollo from 'helpers/mock_apollo_helper';
import SecretFormWrapper from 'ee/ci/secrets/components/secret_form/secret_form_wrapper.vue';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import {
  mockGroupEnvironments,
  mockProjectEnvironments,
  mockProjectBranches,
  mockProjectSecretQueryResponse,
  mockGroupSecretQueryResponse,
} from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);
const { bindInternalEventDocument } = useMockInternalEventsTracking();

describe('SecretFormWrapper component', () => {
  let wrapper;
  let mockApollo;
  let mockGroupEnvQuery;
  let mockProjectEnvQuery;
  let mockProjectBranchesResponse;
  let mockSecretQuery;

  const mockRouter = {
    push: jest.fn(),
  };

  const defaultProps = {
    isEditing: false,
  };

  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findEnvironmentsLoadingIcon = () => findEnvironmentsDropdown().findComponent(GlLoadingIcon);
  const findSecretLoadingIcon = () => wrapper.findByTestId('secret-loading-icon');
  const findPageTitle = () => wrapper.find('h1').text();
  const findSecretForm = () => wrapper.findComponent(SecretForm);

  const createComponent = async ({
    context = ENTITY_PROJECT,
    provide = {},
    props = {},
    stubs = {},
    mocks = {},
    isLoading = false,
    mountFn = shallowMountExtended,
  } = {}) => {
    const contextConfig = SECRETS_MANAGER_CONTEXT_CONFIG[context];
    const handlers = [
      [getGroupEnvironments, mockGroupEnvQuery],
      [getProjectEnvironments, mockProjectEnvQuery],
      [getProjectBranches, mockProjectBranchesResponse],
      [contextConfig.getSecretDetails.query, mockSecretQuery],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretFormWrapper, {
      apolloProvider: mockApollo,
      provide: {
        contextConfig: SECRETS_MANAGER_CONTEXT_CONFIG[context],
        entitlement: null,
        fullPath: 'full/path/to/entity',
        isReadOnly: false,
        ...provide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs,
      mocks,
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  beforeEach(() => {
    mockGroupEnvQuery = jest.fn().mockResolvedValue(mockGroupEnvironments);
    mockProjectEnvQuery = jest.fn().mockResolvedValue(mockProjectEnvironments);
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
    mockSecretQuery = jest.fn();
  });

  describe('create form', () => {
    beforeEach(() => {
      createComponent({ props: { isEditing: false } });
    });

    it('shows create form', () => {
      expect(findPageTitle()).toBe('New secret');
    });

    it('passes correct props to secret form', () => {
      expect(findSecretForm().props()).toMatchObject({
        isEditing: false,
        secretData: null,
      });
    });
  });

  describe('environments dropdown', () => {
    it('uses group environments query for group secrets app', async () => {
      await createComponent({
        context: ENTITY_GROUP,
        stubs: { SecretForm, CiEnvironmentsDropdown },
      });

      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(0);
      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(1);

      expect(findEnvironmentsDropdown().props('environments')).toEqual([
        'group_env_development',
        'group_env_production',
        'group_env_staging',
      ]);
    });

    it('uses project environments query for project secrets app', async () => {
      await createComponent({
        context: ENTITY_PROJECT,
        stubs: { SecretForm, CiEnvironmentsDropdown },
      });

      expect(mockGroupEnvQuery).toHaveBeenCalledTimes(0);
      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(1);

      expect(findEnvironmentsDropdown().props('environments')).toEqual([
        'project_env_development',
        'project_env_production',
        'project_env_staging',
      ]);
    });

    describe('while query is being fetched', () => {
      it('shows a loading icon', async () => {
        await createComponent({ isLoading: true, mountFn: mountExtended });

        expect(findEnvironmentsLoadingIcon().exists()).toBe(true);
      });
    });

    describe('when query is successful', () => {
      beforeEach(async () => {
        await createComponent({ isLoading: false, mountFn: mountExtended });
      });

      it('does not show a loading icon', () => {
        expect(findEnvironmentsLoadingIcon().exists()).toBe(false);
      });

      it('does not call createAlert', () => {
        expect(createAlert).not.toHaveBeenCalled();
      });

      it('query is called with the correct variables', () => {
        expect(mockProjectEnvQuery).toHaveBeenLastCalledWith({
          first: 30,
          fullPath: 'full/path/to/entity',
          search: '',
        });
      });
    });

    describe('when query is unsuccessful', () => {
      const error = new Error('GraphQL error');

      beforeEach(async () => {
        mockProjectEnvQuery.mockRejectedValue(error);
        await createComponent({ isLoading: false });
      });

      it('calls createAlert with the expected error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: ENVIRONMENT_FETCH_ERROR,
          captureError: true,
          error,
        });
      });
    });

    it('refetches environments when search term is present', async () => {
      await createComponent();

      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(1);
      expect(mockProjectEnvQuery).toHaveBeenCalledWith(expect.objectContaining({ search: '' }));

      await findSecretForm().vm.$emit('search-environment', 'staging');

      expect(mockProjectEnvQuery).toHaveBeenCalledTimes(2);
      expect(mockProjectEnvQuery).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'staging' }),
      );
    });
  });

  const PROJECT_SECRET = {
    name: 'PROJECT_SECRET',
    branch: 'main',
    description: 'This is a project secret',
    environment: 'staging',
  };

  const GROUP_SECRET = {
    name: 'GROUP_SECRET',
    description: 'This is a group secret',
    environment: 'staging',
  };

  describe.each`
    context           | secret            | mockResponse                      | visitEvent
    ${ENTITY_PROJECT} | ${PROJECT_SECRET} | ${mockProjectSecretQueryResponse} | ${'visit_project_secrets_manager'}
    ${ENTITY_GROUP}   | ${GROUP_SECRET}   | ${mockGroupSecretQueryResponse}   | ${'visit_group_secrets_manager'}
  `('accessing the form in $context context', ({ context, secret, mockResponse, visitEvent }) => {
    describe('edit form', () => {
      beforeEach(async () => {
        mockSecretQuery.mockResolvedValue(mockResponse());
        createComponent({ context, props: { isEditing: true, secretName: secret.name } });

        await nextTick();
      });

      it('shows edit secret form', () => {
        expect(findPageTitle()).toBe(`Edit ${secret.name}`);
      });

      it('shows loading icon while secret is being fetched', async () => {
        createComponent({
          context,
          isLoading: true,
          props: { isEditing: true, secretName: secret.name },
        });

        await nextTick();

        expect(findSecretLoadingIcon().exists()).toBe(true);
      });

      it('passes correct props to secret form', () => {
        expect(findSecretForm().props()).toMatchObject({
          isEditing: true,
          secretData: secret,
        });
      });

      describe('when secret query fails', () => {
        const error = new Error('GraphQL error: Failed to fetch secret');

        beforeEach(async () => {
          mockSecretQuery.mockRejectedValue(error);
          await createComponent({ context, props: { isEditing: true, secretName: 'SECRET_KEY' } });
        });

        it('calls createAlert with error details', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Failed to fetch secret',
            captureError: true,
            error,
          });
        });
      });
    });

    describe('event tracking', () => {
      it('tracks page visit to create form', async () => {
        await createComponent({ context });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledTimes(1);
        expect(trackEventSpy).toHaveBeenCalledWith(visitEvent, { label: 'create_form' }, undefined);
      });

      it('tracks page visit to edit form', async () => {
        mockSecretQuery.mockResolvedValue(mockResponse());
        await createComponent({ context, props: { isEditing: true } });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        expect(trackEventSpy).toHaveBeenCalledTimes(1);
        expect(trackEventSpy).toHaveBeenCalledWith(visitEvent, { label: 'edit_form' }, undefined);
      });
    });
  });

  describe('when entitlement state is trial eligible', () => {
    beforeEach(async () => {
      await createComponent({
        provide: {
          entitlement: { state: ENTITLEMENT_STATE_TRIAL_ELIGIBLE },
          glFeatures: { secretsManagerPaidExperience: true },
        },
        mocks: { $router: mockRouter },
      });
    });

    it('redirects to the index route', () => {
      expect(mockRouter.push).toHaveBeenCalledWith({ name: INDEX_ROUTE_NAME });
    });
  });
});
