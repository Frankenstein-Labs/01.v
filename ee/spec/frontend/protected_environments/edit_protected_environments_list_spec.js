import { GlAvatar, GlButton, GlSprintf } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { TEST_HOST } from 'helpers/test_constants';
import axios from '~/lib/utils/axios_utils';
import AccessDropdown from '~/projects/settings/components/access_dropdown.vue';
import GroupsAccessDropdown from 'ee/groups/settings/components/access_dropdown.vue';
import { createStore } from 'ee/protected_environments/store/edit';
import AddRuleModal from 'ee/protected_environments/add_rule_modal.vue';
import AddApprovers from 'ee/protected_environments/add_approvers.vue';
import EditProtectedEnvironmentRulesCard from 'ee/protected_environments/edit_protected_environment_rules_card.vue';
import EditProtectedEnvironmentsList from 'ee/protected_environments/edit_protected_environments_list.vue';
import ProtectedEnvironments from 'ee/protected_environments/protected_environments.vue';
import {
  DEPLOYER_RULE_KEY,
  APPROVER_RULE_KEY,
  INHERITED_GROUPS,
} from 'ee/protected_environments/constants';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { MAINTAINER_ACCESS_LEVEL, DEVELOPER_ACCESS_LEVEL } from './constants';

const DEFAULT_ENVIRONMENTS = [
  {
    name: 'staging',
    deploy_access_levels: [
      {
        id: 1,
        access_level: DEVELOPER_ACCESS_LEVEL,
        access_level_description: 'Deployers + Maintainers',
        group_id: null,
        user_id: null,
      },
      {
        id: 2,
        group_id: 1,
        group_inheritance_type: INHERITED_GROUPS,
        access_level_description: 'Some group',
        access_level: null,
        user_id: null,
      },
      {
        id: 3,
        user_id: 1,
        access_level_description: 'Some user',
        access_level: null,
        group_id: null,
      },
    ],
    approval_rules: [
      {
        id: 1,
        access_level: 30,
        access_level_description: 'Deployers + Maintainers',
        group_id: null,
        user_id: null,
        required_approvals: 1,
      },
      {
        id: 2,
        group_id: 1,
        group_inheritance_type: INHERITED_GROUPS,
        access_level_description: 'Some group',
        access_level: null,
        user_id: null,
        required_approvals: 1,
      },
      {
        id: 3,
        user_id: 1,
        access_level_description: 'Some user',
        access_level: null,
        group_id: null,
        required_approvals: 1,
      },
    ],
  },
];

const NO_APPROVAL_RULES_ENVIRONMENTS = [
  {
    ...DEFAULT_ENVIRONMENTS[0],
    approval_rules: [],
  },
];

const DEFAULT_PROJECT_ID = '8';
const DEFAULT_ACCESS_LEVELS_DATA = [
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

const API_LINK = `${TEST_HOST}/docs/api.md`;
const DOCS_LINK = `${TEST_HOST}/docs/protected_environments.md`;

Vue.use(Vuex);

describe('ee/protected_environments/edit_protected_environments_list.vue', () => {
  let store;
  let wrapper;
  let mock;

  const createComponent = async ({ entityType = 'projects', stubGlSprintf = false } = {}) => {
    store = createStore({ entityId: DEFAULT_PROJECT_ID, entityType });

    wrapper = mountExtended(EditProtectedEnvironmentsList, {
      store,
      provide: {
        accessLevelsData: DEFAULT_ACCESS_LEVELS_DATA,
        apiLink: API_LINK,
        docsLink: DOCS_LINK,
        entityType,
      },
      stubs: {
        GlSprintf: stubGlSprintf,
      },
    });

    await waitForPromises();
  };

  const findDeployerDeleteButton = () => wrapper.findByTitle('Delete deployer rule');
  const findApproverDeleteButton = () => wrapper.findByTitle('Delete approver rule');
  const findApproverEditButton = (id) => wrapper.findByTestId(`edit-approver-button-${id}`);
  const findInheritanceToggle = (id) =>
    wrapper.findComponentByTestId(`approval-inheritance-toggle-${id}`);
  const findApproverSaveButton = () => wrapper.findByRole('button', { name: 'Save' });
  const findApprovalsInput = () =>
    wrapper.findByRole('textbox', { name: 'Required approval count' });
  const findProtectedEnvironments = () => wrapper.findComponent(ProtectedEnvironments);
  const findItemToggleButton = () =>
    wrapper.findComponentByTestId('protected-environment-item-toggle');
  const findAddRuleModal = () => wrapper.findComponent(AddRuleModal);
  const findAddApprovers = () => wrapper.findComponent(AddApprovers);

  describe('on the project level', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      window.gon = {
        api_version: 'v4',
        abilities: { adminProject: true },
      };
      mock
        .onGet('/api/v4/projects/8/protected_environments/')
        .reply(HTTP_STATUS_OK, DEFAULT_ENVIRONMENTS);
      mock
        .onGet('/api/v4/groups/1/members/all')
        .reply(HTTP_STATUS_OK, [{ name: 'root', avatar_url: '/avatar.png' }]);
      mock
        .onGet('/api/v4/users/1')
        .reply(HTTP_STATUS_OK, { name: 'root', avatar_url: '/avatar.png' });
      mock.onGet('/api/v4/projects/8/members').reply(HTTP_STATUS_OK, [
        {
          name: 'root',
          access_level: MAINTAINER_ACCESS_LEVEL.toString(),
          avatar_url: '/avatar.png',
        },
      ]);
    });

    afterEach(() => {
      mock.restore();
      mock.resetHistory();
    });

    it('shows a header for the protected environment', async () => {
      await createComponent();

      expect(wrapper.findByRole('button', { name: 'staging' }).exists()).toBe(true);
    });

    it('shows member avatars in each row', async () => {
      await createComponent();

      const avatars = wrapper.findAllComponents(GlAvatar).wrappers;

      expect(avatars).toHaveLength(6);
      avatars.forEach((avatar) => expect(avatar.props('src')).toBe('/avatar.png'));
    });

    it('shows the description of the rule', async () => {
      const [{ deploy_access_levels: deployAccessLevels, approval_rules: approvalRules }] =
        DEFAULT_ENVIRONMENTS;

      const ruleDescriptions = [
        ...deployAccessLevels.map((d) => d.access_level_description),
        ...approvalRules.map((a) => a.access_level_description),
      ];

      await createComponent();

      const descriptions = wrapper.findAllByTestId('rule-description').wrappers;

      descriptions.forEach((description, i) => {
        expect(description.text()).toBe(ruleDescriptions[i]);
      });
    });

    describe('approvals empty state', () => {
      beforeEach(() => {
        mock
          .onGet('/api/v4/projects/8/protected_environments/')
          .reply(HTTP_STATUS_OK, NO_APPROVAL_RULES_ENVIRONMENTS);
      });

      it('has a copy', async () => {
        await createComponent({ stubGlSprintf: true });

        expect(wrapper.findComponent(GlSprintf).attributes('message')).toBe(
          'This environment has no approval rules set up. %{linkStart}Learn more about deployment approvals.%{linkEnd}',
        );
      });

      it('has a link', async () => {
        await createComponent();

        expect(wrapper.findComponent(HelpPageLink).attributes('href')).toBe(
          '/help/ci/environments/deployment_approvals',
        );
      });
    });

    describe('add deployer rule', () => {
      let environment;
      let dropdown;

      beforeEach(async () => {
        [environment] = DEFAULT_ENVIRONMENTS;

        await createComponent();

        wrapper
          .findComponent(EditProtectedEnvironmentRulesCard)
          .vm.$emit('add-rule', { environment, ruleKey: DEPLOYER_RULE_KEY });

        await nextTick();

        dropdown = wrapper.findComponent(AccessDropdown);
      });

      it('titles the modal appropriately', () => {
        expect(findAddRuleModal().props('title')).toBe('Create deployment rule');
      });

      it('puts the access level dropdown into the modal form', () => {
        expect(dropdown.exists()).toBe(true);
      });

      it('sends new rules to be added', async () => {
        mock.onPut().reply(HTTP_STATUS_OK);

        const rule = [{ user_id: 5 }];
        dropdown.vm.$emit('hidden', rule);

        findAddRuleModal().vm.$emit('save-rule');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);

        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({
          name: environment.name,
          deploy_access_levels: rule,
        });
      });
    });

    describe('deployer delete rule', () => {
      it('sends the deleted rule with _destroy set', async () => {
        const [environment] = DEFAULT_ENVIRONMENTS;

        await createComponent();

        findItemToggleButton().vm.$emit('click');

        const button = findDeployerDeleteButton();

        mock.onPut().reply(HTTP_STATUS_OK);

        const destroyedRule = {
          access_level: DEVELOPER_ACCESS_LEVEL,
          access_level_description: 'Deployers + Maintainers',
          _destroy: true,
        };

        button.trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);

        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({
          name: environment.name,
          deploy_access_levels: [destroyedRule],
        });
      });

      it('hides the button if there is only one rule', async () => {
        const [environment] = DEFAULT_ENVIRONMENTS;
        const [rule] = environment.deploy_access_levels;
        mock.onGet('/api/v4/projects/8/protected_environments/').reply(HTTP_STATUS_OK, [
          {
            ...environment,
            deploy_access_levels: [rule],
          },
        ]);

        await createComponent();

        findItemToggleButton().vm.$emit('click');

        const button = findDeployerDeleteButton();

        expect(button.exists()).toBe(false);
      });
    });

    describe('add approval rule', () => {
      let environment;

      beforeEach(async () => {
        [environment] = DEFAULT_ENVIRONMENTS;

        await createComponent();

        wrapper
          .findComponent(EditProtectedEnvironmentRulesCard)
          .vm.$emit('add-rule', { environment, ruleKey: APPROVER_RULE_KEY });

        await nextTick();
      });

      it('titles the modal appropriately', () => {
        expect(findAddRuleModal().props('title')).toBe('Create approval rule');
      });

      it('puts the access level dropdown into the modal form', () => {
        expect(findAddApprovers().exists()).toBe(true);
      });

      it('provides current rules list for the the access level dropdown', () => {
        expect(findAddApprovers().props('approvalRules')).toBe(environment[APPROVER_RULE_KEY]);
      });

      it('sends new rules to be added', async () => {
        mock.onPut().reply(HTTP_STATUS_OK);

        const rule = [{ user_id: 5, required_approvals: 3 }];
        findAddApprovers().vm.$emit('change', rule);

        findAddRuleModal().vm.$emit('save-rule');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);

        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({ name: environment.name, approval_rules: rule });
      });
    });

    describe('approver delete rule', () => {
      it('sends the deleted rule with _destroy set', async () => {
        const [environment] = DEFAULT_ENVIRONMENTS;

        await createComponent();

        wrapper.findComponent(GlButton).vm.$emit('click');

        const button = findApproverDeleteButton();

        mock.onPut().reply(HTTP_STATUS_OK);

        const destroyedRule = {
          access_level: DEVELOPER_ACCESS_LEVEL,
          access_level_description: 'Deployers + Maintainers',
          _destroy: true,
        };

        button.trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);

        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({
          name: environment.name,
          approval_rules: [destroyedRule],
        });
      });
    });

    describe('approver edit rule', () => {
      let environment;

      beforeEach(async () => {
        [environment] = DEFAULT_ENVIRONMENTS;
        await createComponent();

        findItemToggleButton().vm.$emit('click');

        await nextTick();
      });

      it('allows editing of an approval rule', async () => {
        const [rule] = environment.approval_rules;
        const value = '2';

        mock.onPut().reply(HTTP_STATUS_OK);

        const button = findApproverEditButton(rule.id);

        await button.trigger('click');

        const input = findApprovalsInput();

        expect(input.exists()).toBe(true);

        await input.setValue(value);

        findApproverSaveButton().trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({
          name: environment.name,
          approval_rules: [
            {
              id: rule.id,
              access_level: rule.access_level,
              access_level_description: rule.access_level_description,
              required_approvals: value,
            },
          ],
        });
      });

      it('shows a toggle for group ID rules', async () => {
        const [, rule] = environment.approval_rules;
        mock.onPut().reply(HTTP_STATUS_OK);

        const button = findApproverEditButton(rule.id);

        expect(findInheritanceToggle(rule.id).props('value')).toBe(true);
        expect(findInheritanceToggle(rule.id).props('disabled')).toBe(true);

        await button.trigger('click');

        expect(findInheritanceToggle(rule.id).props('value')).toBe(true);
        expect(findInheritanceToggle(rule.id).props('disabled')).toBe(false);

        await findInheritanceToggle(rule.id).vm.$emit('change', false);

        findApproverSaveButton().trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        const [{ data }] = mock.history.put;
        expect(JSON.parse(data)).toMatchObject({
          name: environment.name,
          approval_rules: [
            {
              id: rule.id,
              group_id: rule.group_id,
              access_level_description: rule.access_level_description,
              group_inheritance_type: 0,
            },
          ],
        });
      });

      it('hides the toggle for non-group rules', () => {
        const { id } = environment.approval_rules.find(({ user_id: userId }) => userId);

        expect(findInheritanceToggle(id).exists()).toBe(false);
      });

      it('hides the edit button for user rules', () => {
        const { id } = environment.approval_rules.find(({ user_id: userId }) => userId);
        const button = findApproverEditButton(id);

        expect(button.exists()).toBe(false);
      });
    });

    describe('unprotect environment', () => {
      it('unprotects an environment when emitted', async () => {
        const [environment] = DEFAULT_ENVIRONMENTS;

        mock.onDelete().reply(HTTP_STATUS_OK);

        await createComponent();

        findProtectedEnvironments().vm.$emit('unprotect', environment);
        await waitForPromises();

        expect(mock.history.delete).toHaveLength(1);

        const [{ url }] = mock.history.delete;
        expect(url).toBe(`/api/v4/projects/8/protected_environments/${environment.name}`);
      });
    });
  });

  describe('on the group level', () => {
    const [environment] = DEFAULT_ENVIRONMENTS;

    beforeEach(async () => {
      mock = new MockAdapter(axios);
      window.gon = { api_version: 'v4' };
      mock
        .onGet('/api/v4/groups/8/protected_environments/')
        .reply(HTTP_STATUS_OK, DEFAULT_ENVIRONMENTS);
      mock
        .onGet('/api/v4/groups/1/members/all')
        .reply(HTTP_STATUS_OK, [{ name: 'root', avatar_url: '/avatar.png' }]);
      mock
        .onGet('/api/v4/users/1')
        .reply(HTTP_STATUS_OK, { name: 'root', avatar_url: '/avatar.png' });
      mock.onGet('/api/v4/groups/8/members').reply(HTTP_STATUS_OK, [
        {
          name: 'root',
          access_level: MAINTAINER_ACCESS_LEVEL.toString(),
          avatar_url: '/avatar.png',
        },
      ]);

      await createComponent({ entityType: 'groups' });
    });

    afterEach(() => {
      mock.restore();
      mock.resetHistory();
    });

    it('requests the protected environments for the group', () => {
      expect(mock.history.get[0].url).toBe('/api/v4/groups/8/protected_environments/');
    });

    describe('approvals empty state', () => {
      beforeEach(() => {
        mock
          .onGet('/api/v4/groups/8/protected_environments/')
          .reply(HTTP_STATUS_OK, NO_APPROVAL_RULES_ENVIRONMENTS);
      });

      it('has a copy', async () => {
        await createComponent({ entityType: 'groups', stubGlSprintf: true });

        expect(wrapper.findComponent(GlSprintf).attributes('message')).toBe(
          'This environment has no approval rules set up. %{linkStart}Learn more about deployment approvals.%{linkEnd}',
        );
      });

      it('has a link', async () => {
        await createComponent({ entityType: 'groups' });

        expect(wrapper.findComponent(HelpPageLink).attributes('href')).toBe(
          '/help/ci/environments/deployment_approvals',
        );
      });
    });

    describe('add deployer rule', () => {
      let dropdown;

      beforeEach(async () => {
        wrapper
          .findComponent(EditProtectedEnvironmentRulesCard)
          .vm.$emit('add-rule', { environment, ruleKey: DEPLOYER_RULE_KEY });

        await nextTick();

        dropdown = wrapper.findComponent(GroupsAccessDropdown);
      });

      it('renders the group access level dropdown in the modal form', () => {
        expect(dropdown.props()).toMatchObject({
          label: 'Select users',
          accessLevelsData: DEFAULT_ACCESS_LEVELS_DATA,
          inherited: true,
        });
      });

      it('sends new rules to the groups endpoint', async () => {
        mock.onPut().reply(HTTP_STATUS_OK);

        const rule = [{ user_id: 5 }];
        dropdown.vm.$emit('hidden', rule);

        findAddRuleModal().vm.$emit('save-rule');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        expect(mock.history.put[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });

    describe('deployer delete rule', () => {
      it('sends the deleted rule to the groups endpoint', async () => {
        findItemToggleButton().vm.$emit('click');

        const button = findDeployerDeleteButton();

        mock.onPut().reply(HTTP_STATUS_OK);
        button.trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        expect(mock.history.put[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });

    describe('add approval rule', () => {
      it('sends new rules to the groups endpoint', async () => {
        mock.onPut().reply(HTTP_STATUS_OK);
        wrapper
          .findComponent(EditProtectedEnvironmentRulesCard)
          .vm.$emit('add-rule', { environment, ruleKey: APPROVER_RULE_KEY });

        await nextTick();

        const rule = [{ user_id: 5, required_approvals: 3 }];
        findAddApprovers().vm.$emit('change', rule);

        findAddRuleModal().vm.$emit('save-rule');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        expect(mock.history.put[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });

    describe('approver delete rule', () => {
      it('sends the deleted rule to the groups endpoint', async () => {
        wrapper.findComponent(GlButton).vm.$emit('click');
        mock.onPut().reply(HTTP_STATUS_OK);

        findApproverDeleteButton().trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        expect(mock.history.put[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });

    describe('approver edit rule', () => {
      it('sends the editing request to the groups endpoint', async () => {
        const [rule] = environment.approval_rules;

        mock.onPut().reply(HTTP_STATUS_OK);

        findItemToggleButton().vm.$emit('click');
        await nextTick();
        await findApproverEditButton(rule.id).trigger('click');
        await findApprovalsInput().setValue('2');

        findApproverSaveButton().trigger('click');

        await waitForPromises();

        expect(mock.history.put).toHaveLength(1);
        expect(mock.history.put[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });

    describe('unprotect environment', () => {
      it('sends unprotect request to the groups endpoint', async () => {
        mock.onDelete().reply(HTTP_STATUS_OK);

        findProtectedEnvironments().vm.$emit('unprotect', environment);
        await waitForPromises();

        expect(mock.history.delete).toHaveLength(1);
        expect(mock.history.delete[0].url).toBe(
          `/api/v4/groups/8/protected_environments/${environment.name}`,
        );
      });
    });
  });
});
