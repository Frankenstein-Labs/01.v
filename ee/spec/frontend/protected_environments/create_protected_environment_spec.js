import MockAdapter from 'axios-mock-adapter';
import { GlAlert, GlCollapsibleListbox, GlForm } from '@gitlab/ui';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TEST_HOST } from 'helpers/test_constants';
import Api from 'ee/api';
import axios from '~/lib/utils/axios_utils';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import GroupsAccessDropdown from 'ee/groups/settings/components/access_dropdown.vue';
import { ACCESS_LEVELS } from 'ee/protected_environments/constants';
import AddApprovers from 'ee/protected_environments/add_approvers.vue';
import CreateProtectedEnvironment from 'ee/protected_environments/create_protected_environment.vue';
import { HTTP_STATUS_BAD_REQUEST, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

const SEARCH_URL = '/search';
const PROJECT_ID = '0';
const API_LINK = `${TEST_HOST}/docs/api.md`;
const DOCS_LINK = `${TEST_HOST}/docs/protected_environments.md`;
const accessLevelsData = [
  {
    id: 40,
    text: 'Maintainers',
    before_divider: true,
  },
  {
    id: 30,
    text: 'Developers + Maintainers',
    before_divider: true,
  },
];
const tiers = ['production', 'staging'];

describe('ee/protected_environments/create_protected_environment.vue', () => {
  useMockLocationHelper();

  let wrapper;
  let mockAxios;

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEnvironmentsListbox = () =>
    wrapper.findByTestId('create-environment').findComponent(GlCollapsibleListbox);
  const findAccessDropdown = () =>
    wrapper.findByTestId('create-deployer-dropdown').findComponent(AccessDropdown);
  const findGroupsAccessDropdown = () =>
    wrapper.findByTestId('create-deployer-dropdown').findComponent(GroupsAccessDropdown);
  const findAddApprovers = () => wrapper.findComponent(AddApprovers);
  const findCancelButton = () => wrapper.findByTestId('cancel-button');
  const findForm = () => wrapper.findComponent(GlForm);

  beforeEach(() => {
    window.gon = {
      api_version: 'v4',
      deploy_access_levels: {
        roles: [],
      },
      abilities: { adminProject: true },
    };
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  const createComponent = ({
    searchUnprotectedEnvironmentsUrl = SEARCH_URL,
    entityId = PROJECT_ID,
    entityType = 'projects',
  } = {}) => {
    wrapper = mountExtended(CreateProtectedEnvironment, {
      provide: {
        apiLink: API_LINK,
        docsLink: DOCS_LINK,
        searchUnprotectedEnvironmentsUrl,
        entityId,
        entityType,
        accessLevelsData,
        tiers,
      },
    });
  };

  const submitForm = async (
    deployAccessLevels = [{ user_id: 1 }],
    name = 'production',
    requiredApprovalCount = '3',
  ) => {
    mockAxios.onGet('/api/v4/users/1').reply(HTTP_STATUS_OK, {
      name: 'root',
      web_url: '/root',
      avatar_url: '/root.png',
      id: 1,
    });
    findAccessDropdown().vm.$emit('select', deployAccessLevels);
    findEnvironmentsListbox().vm.$emit('select', name);
    findAddApprovers().vm.$emit(
      'change',
      deployAccessLevels.map((rule) => ({ ...rule, required_approvals: requiredApprovalCount })),
    );
    await findForm().trigger('submit');
  };

  const submitGroupsForm = async (deployAccessLevels, name, requiredApprovalCount) => {
    findEnvironmentsListbox().vm.$emit('select', name);
    findGroupsAccessDropdown().vm.$emit('select', deployAccessLevels);
    findAddApprovers().vm.$emit(
      'change',
      deployAccessLevels.map((rule) => ({ ...rule, required_approvals: requiredApprovalCount })),
    );
    await findForm().trigger('submit');
  };

  describe('on project level', () => {
    it('renders AccessDropdown and passes down the props', () => {
      createComponent();
      const dropdown = findAccessDropdown();

      expect(dropdown.props()).toMatchObject({
        accessLevel: ACCESS_LEVELS.DEPLOY,
        label: 'Select users',
      });
    });

    it('emits cancel event when the cancel button is clicked', () => {
      createComponent();
      findCancelButton().trigger('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });

    it('searches the environment name', async () => {
      const query = 'staging';
      mockAxios
        .onGet(SEARCH_URL, { params: { query: '' } })
        .reply(HTTP_STATUS_OK, ['production', query]);
      createComponent();
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      mockAxios.onGet(SEARCH_URL, { params: { query } }).reply(HTTP_STATUS_OK, [query]);

      const environmentSearch = findEnvironmentsListbox();
      environmentSearch.vm.$emit('search', query);
      jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
      await waitForPromises();

      expect(environmentSearch.props('items')).toEqual([{ value: query, text: query }]);
    });

    it('renders a dropdown for selecting approvers', () => {
      createComponent();

      const approvers = findAddApprovers();

      expect(approvers.props()).toMatchObject({
        disabled: false,
      });
    });

    it('should make a request when submit is clicked', async () => {
      createComponent();

      jest.spyOn(Api, 'createProtectedEnvironment');
      const deployAccessLevels = [{ user_id: 1 }];
      const name = 'production';
      const requiredApprovalCount = '3';

      await submitForm(deployAccessLevels, name, requiredApprovalCount);

      expect(Api.createProtectedEnvironment).toHaveBeenCalledWith(PROJECT_ID, 'projects', {
        deploy_access_levels: deployAccessLevels,
        approval_rules: [{ user_id: 1, required_approvals: requiredApprovalCount }],
        name,
      });
    });

    describe('on failed protected environment', () => {
      it.each([
        {
          statusCode: HTTP_STATUS_BAD_REQUEST,
          expectedMessage: 'Failed to protect the environment.',
        },
        {
          statusCode: HTTP_STATUS_BAD_REQUEST,
          responseData: { message: 'Serverside message' },
          expectedMessage: 'Failed to protect the environment. Serverside message',
        },
      ])(
        'should show a correct error message',
        async ({ statusCode, expectedMessage, responseData }) => {
          mockAxios.onPost().replyOnce(statusCode, responseData);
          createComponent();
          await submitForm();
          await waitForPromises();

          expect(findAlert().text()).toBe(expectedMessage);
        },
      );
    });
  });

  describe('on group level', () => {
    beforeEach(() => {
      createComponent({ entityType: 'groups' });
    });

    it('renders AccessDropdown and passes down the props', () => {
      const dropdown = findGroupsAccessDropdown();

      expect(dropdown.props()).toMatchObject({
        accessLevelsData,
        label: 'Select users',
        inherited: true,
      });
    });

    it('renders environment tier selector', () => {
      expect(findEnvironmentsListbox().props('toggleText')).toBe('Select environment tier');
      expect(findEnvironmentsListbox().props('items')).toEqual([
        { value: 'production', text: 'production' },
        { value: 'staging', text: 'staging' },
      ]);
    });

    it('renders a dropdown for selecting approvers', () => {
      const approvers = findAddApprovers();

      expect(approvers.props()).toMatchObject({
        disabled: false,
      });
    });

    it('should make a request when submit is clicked', async () => {
      jest.spyOn(Api, 'createProtectedEnvironment');
      const deployAccessLevels = [{ group_id: 1 }];
      const name = 'production';
      const requiredApprovalCount = '3';

      await submitGroupsForm(deployAccessLevels, name, requiredApprovalCount);

      expect(Api.createProtectedEnvironment).toHaveBeenCalledWith(PROJECT_ID, 'groups', {
        deploy_access_levels: deployAccessLevels,
        approval_rules: [{ group_id: 1, required_approvals: requiredApprovalCount }],
        name,
      });
    });
  });
});
