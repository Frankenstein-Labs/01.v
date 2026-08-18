import { GlEmptyState, GlLoadingIcon, GlSprintf, GlLink } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import EscalationPoliciesWrapper, {
  i18n,
} from 'ee/escalation_policies/components/escalation_policies_wrapper.vue';
import EscalationPolicy from 'ee/escalation_policies/components/escalation_policy.vue';
import AddEscalationPolicyModal from 'ee/escalation_policies/components/add_edit_escalation_policy_modal.vue';
import getEscalationPoliciesQuery from 'ee/escalation_policies/graphql/queries/get_escalation_policies.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import mockEscalationPolicies from './mocks/mockPolicies.json';

Vue.use(VueApollo);

// Normalize a raw mock policy into the exact shape the `EscalationPolicy`
// GraphQL fragment selects, so the mock Apollo cache can store it completely.
const toPolicyNode = (policy) => ({
  __typename: 'EscalationPolicyType',
  id: `gid://gitlab/IncidentManagement::EscalationPolicy/${policy.id}`,
  name: policy.name,
  description: policy.description,
  rules: (policy.rules ?? []).map((rule, index) => ({
    __typename: 'EscalationRuleType',
    id: rule.id,
    status: rule.status,
    elapsedTimeSeconds: rule.elapsedTimeSeconds,
    oncallSchedule: rule.oncallSchedule
      ? {
          __typename: 'IncidentManagementOncallSchedule',
          iid: rule.oncallSchedule.iid,
          name: rule.oncallSchedule.name,
        }
      : null,
    user: rule.user
      ? {
          __typename: 'UserCore',
          id: rule.user.id ?? `gid://gitlab/User/${index + 1}`,
          username: rule.user.username,
          name: rule.user.name,
          avatarUrl: rule.user.avatarUrl,
        }
      : null,
  })),
});

const escalationPoliciesResponse = (policies) => ({
  data: {
    project: {
      __typename: 'Project',
      id: 'gid://gitlab/Project/1',
      incidentManagementEscalationPolicies: {
        __typename: 'EscalationPolicyTypeConnection',
        nodes: policies.map(toPolicyNode),
      },
    },
  },
});

describe('Escalation Policies Wrapper', () => {
  let wrapper;
  let showToast;
  const emptyEscalationPoliciesSvgPath = 'illustration/path.svg';
  const projectPath = 'group/project';
  const accessLevelDescriptionPath = 'group/project/-/project_members?sort=access_level_desc';

  async function mountComponent({
    loading = false,
    escalationPolicies = [],
    userCanCreateEscalationPolicy = true,
    isShallowExtendedMount = true,
  } = {}) {
    const queryHandler = loading
      ? jest.fn().mockReturnValue(new Promise(() => {}))
      : jest.fn().mockResolvedValue(escalationPoliciesResponse(escalationPolicies));

    const mountProps = {
      apolloProvider: createMockApollo([[getEscalationPoliciesQuery, queryHandler]]),
      provide: {
        emptyEscalationPoliciesSvgPath,
        projectPath,
        userCanCreateEscalationPolicy,
        accessLevelDescriptionPath,
      },
      mocks: {
        $toast: { show: showToast },
      },
      stubs: {
        GlSprintf,
      },
    };

    wrapper = isShallowExtendedMount
      ? shallowMountExtended(EscalationPoliciesWrapper, mountProps)
      : mountExtended(EscalationPoliciesWrapper, mountProps);

    if (!loading) {
      await waitForPromises();
    }
  }

  beforeEach(async () => {
    showToast = jest.fn();
    await mountComponent();
  });

  const findLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findEscalationPolicies = () => wrapper.findAllComponents(EscalationPolicy);
  const findEscalationPolicyModal = () => wrapper.findComponent(AddEscalationPolicyModal);

  describe.each`
    state             | loading  | escalationPolicies        | showsEmptyState | showsLoader
    ${'is loading'}   | ${true}  | ${[]}                     | ${false}        | ${true}
    ${'is empty'}     | ${false} | ${[]}                     | ${true}         | ${false}
    ${'has policies'} | ${false} | ${mockEscalationPolicies} | ${false}        | ${false}
  `(`When $state`, ({ loading, escalationPolicies, showsEmptyState, showsLoader }) => {
    beforeEach(async () => {
      await mountComponent({
        loading,
        escalationPolicies,
      });
    });

    it(`does ${loading ? 'show' : 'not show'} a loader`, () => {
      expect(findLoader().exists()).toBe(showsLoader);
    });

    it(`does ${showsEmptyState ? 'show' : 'not show'} an empty state`, () => {
      expect(findEmptyState().exists()).toBe(showsEmptyState);
    });

    it(`does ${escalationPolicies.length ? 'show' : 'not show'} escalation policies`, () => {
      expect(findEscalationPolicies()).toHaveLength(escalationPolicies.length);
    });
  });

  describe('Escalation policy empty state', () => {
    it('should allow to create policy when user is at least a maintainer', async () => {
      await mountComponent({ isShallowExtendedMount: false });

      expect(findEmptyState().props('title')).toBe(i18n.emptyState.title);
      expect(wrapper.findByText(i18n.emptyState.description).exists()).toBe(true);
      expect(wrapper.findByRole('button', { name: i18n.emptyState.button }).exists()).toBe(true);
    });

    it('should show message about role restrictions when user is below maintainer level', async () => {
      await mountComponent({
        userCanCreateEscalationPolicy: false,
        isShallowExtendedMount: false,
      });

      expect(findEmptyState().props('title')).toBe(i18n.emptyState.title);
      expect(wrapper.findComponent(GlLink).exists()).toBe(true);
      expect(wrapper.findByRole('button', { name: i18n.emptyState.button }).exists()).toBe(false);
    });
  });

  describe('Escalation policy created toast', () => {
    it('shows a confirmation toast when a policy is created', async () => {
      await mountComponent({
        loading: false,
        escalationPolicies: mockEscalationPolicies,
      });
      expect(showToast).not.toHaveBeenCalled();

      findEscalationPolicyModal().vm.$emit('policy-created');
      await nextTick();

      expect(showToast).toHaveBeenCalledWith(i18n.policyCreatedAlert.title);
    });
  });
});
